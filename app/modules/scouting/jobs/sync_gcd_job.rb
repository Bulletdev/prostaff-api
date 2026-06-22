# frozen_string_literal: true

module Scouting
  # Nightly job: calls ProStaff-Scraper GCD endpoint and upserts MarketRegistration records.
  #
  # The Scraper is the only Leaguepedia client — Rails never calls Leaguepedia directly.
  # Circuit breaker: if the Scraper is unavailable (UnavailableError), log and abort
  # without raising so the Sidekiq retry mechanism handles it.
  class SyncGcdJob
    include Sidekiq::Job

    sidekiq_options queue: 'default', retry: 3

    LEAGUES = %w[CBLOL LCK LEC LCS LPL].freeze

    def perform(leagues = LEAGUES)
      count = { upserted: 0, skipped: 0, errors: 0 }
      snapshot_date = Date.current

      Array(leagues).each do |league|
        sync_league(league, snapshot_date, count)
      end

      Rails.logger.info(
        "[SyncGcdJob] Done — upserted=#{count[:upserted]} " \
        "skipped=#{count[:skipped]} errors=#{count[:errors]}"
      )
      enqueue_tag_enrichment
    end

    private

    def sync_league(league, snapshot_date, count)
      records = fetch_from_scraper(league)
      return if records.empty?

      records.each do |record|
        upsert_record(record, snapshot_date, count)
      end
    rescue ProStaffScraperService::UnavailableError => e
      Rails.logger.warn("[SyncGcdJob] Scraper unavailable for league=#{league}: #{e.message}")
      count[:errors] += 1
    rescue StandardError => e
      Rails.logger.error("[SyncGcdJob] Error syncing league=#{league}: #{e.class}: #{e.message}")
      count[:errors] += 1
    end

    def fetch_from_scraper(league)
      ProStaffScraperService.new.fetch_gcd_players(league: league)
    end

    def upsert_record(record, snapshot_date, count)
      MarketRegistration.upsert(
        build_upsert_attrs(record, snapshot_date),
        unique_by: %i[player_external_name],
        update_only: %i[team_name region role residency contract_end_date
                        solo_queue_id solo_queue_server image_url raw_payload
                        snapshot_date tag_enriched]
      )
      count[:upserted] += 1
    rescue StandardError => e
      count[:errors] += 1
      Rails.logger.error("[SyncGcdJob] upsert failed player=#{record['player_name']}: #{e.message}")
    end

    def build_upsert_attrs(record, snapshot_date)
      {
        player_external_name: record['player_name'],
        team_name: record['team_name'],
        region: record['region'],
        role: record['role'],
        residency: record['residency'],
        contract_end_date: parse_date(record['contract_end_date']),
        solo_queue_id: record['solo_queue_id'],
        solo_queue_server: record['solo_queue_server'],
        tag_enriched: false,
        image_url: record['image_url'],
        source: record.fetch('source', 'leaguepedia_gcd'),
        snapshot_date: snapshot_date,
        raw_payload: record
      }
    end

    def enqueue_tag_enrichment
      MarketRegistration
        .where(tag_enriched: false)
        .where.not(solo_queue_id: nil)
        .where.not("solo_queue_id LIKE '%#%'")
        .where(solo_queue_id_override: nil)
        .find_each { |reg| Scouting::EnrichSoloQueueTagJob.perform_async(reg.id) }
    end

    def parse_date(date_str)
      return nil unless date_str.present?

      Date.parse(date_str)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
