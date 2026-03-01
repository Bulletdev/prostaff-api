# frozen_string_literal: true

module Competitive
  # Background job to sync professional match data from the ProStaff Scraper
  # into the organization's CompetitiveMatch records.
  #
  # Fetches enriched matches from the scraper microservice (which indexes data
  # from LoL Esports + Leaguepedia) and imports them via ScraperImporterService.
  # Only `riot_enriched: true` matches (with per-player stats) are imported.
  #
  # @example Enqueue manually
  #   Competitive::SyncScraperMatchesJob.perform_later(
  #     organization.id,
  #     league: 'CBLOL',
  #     our_team: 'paiN Gaming',
  #     limit: 100
  #   )
  #
  class SyncScraperMatchesJob < ApplicationJob
    queue_as :default

    retry_on ProStaffScraperService::UnavailableError, wait: 5.minutes, attempts: 3
    discard_on ProStaffScraperService::UnauthorizedError

    BATCH_SIZE = 50

    # @param organization_id [String] UUID of the organization
    # @param league    [String]  league slug, e.g. 'CBLOL'
    # @param our_team  [String]  optional team name to identify victories
    # @param limit     [Integer] maximum number of matches to import per run
    def perform(organization_id, league:, our_team: nil, limit: 100)
      organization = Organization.find(organization_id)

      Rails.logger.info(
        "[SyncScraperMatchesJob] Starting sync for org=#{organization_id} " \
        "league=#{league} our_team=#{our_team.inspect} limit=#{limit}"
      )

      scraper  = ProStaffScraperService.new
      importer = ScraperImporterService.new(organization)

      totals = { imported: 0, skipped_duplicate: 0, skipped_unenriched: 0, errors: 0 }
      skip = 0

      loop do
        fetch_limit = [BATCH_SIZE, limit - totals[:imported] - totals[:skipped_duplicate]].min
        break if fetch_limit <= 0

        result = scraper.fetch_matches(league: league, limit: fetch_limit, skip: skip)
        matches = result['matches'] || []

        break if matches.empty?

        batch_stats = importer.import_batch(matches, our_team: our_team)
        merge_stats!(totals, batch_stats)

        Rails.logger.info(
          "[SyncScraperMatchesJob] Batch skip=#{skip} fetched=#{matches.size} " \
          "imported=#{batch_stats[:imported]} skipped_dup=#{batch_stats[:skipped_duplicate]}"
        )

        skip += matches.size
        break if matches.size < fetch_limit
      end

      Rails.logger.info(
        "[SyncScraperMatchesJob] Finished org=#{organization_id} league=#{league} " \
        "totals=#{totals.inspect}"
      )

      totals
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "[SyncScraperMatchesJob] Organization #{organization_id} not found: #{e.message}"
    rescue ProStaffScraperService::ScraperError => e
      Rails.logger.error "[SyncScraperMatchesJob] Scraper error for #{league}: #{e.message}"
      raise
    end

    private

    def merge_stats!(totals, batch_stats)
      batch_stats.each { |key, val| totals[key] = totals[key].to_i + val.to_i }
    end
  end
end
