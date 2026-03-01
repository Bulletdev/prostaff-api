# frozen_string_literal: true

module Competitive
  # Scheduled Sidekiq job that orchestrates the full historical backfill pipeline:
  #
  #   1. Triggers the historical backfill on the ProStaff Scraper (Leaguepedia → ES)
  #   2. Polls the scraper's backfill status until it finishes or times out
  #   3. Syncs the newly indexed matches from ES into the Rails DB
  #
  # The scraper's backfill is resumable — re-triggering it skips already-completed
  # tournaments.  This means the job is safe to run on a schedule (e.g. daily):
  # first runs import the full history (~8-12h for CBLOL), subsequent runs only
  # process new or previously-failed tournaments (minutes).
  #
  # Configuration (environment variables):
  #   BACKFILL_LEAGUE    — league to backfill (default: 'CBLOL')
  #   BACKFILL_MIN_YEAR  — earliest year to import (default: 2013)
  #   BACKFILL_OUR_TEAM  — team name for the sync step (default: 'paiN Gaming')
  #   BACKFILL_SYNC_LIMIT — max matches to sync per run (default: 500)
  #
  # @example Run manually from console
  #   Competitive::HistoricalBackfillJob.perform_later
  #
  # @example Check backfill progress
  #   ProStaffScraperService.new.historical_backfill_status(league: 'CBLOL')
  #
  class HistoricalBackfillJob < ApplicationJob
    queue_as :low_priority

    # The scraper may be temporarily unavailable — retry after 10 minutes.
    retry_on ProStaffScraperService::UnavailableError, wait: 10.minutes, attempts: 3
    discard_on ProStaffScraperService::UnauthorizedError

    # How often to poll the scraper for backfill progress (seconds).
    POLL_INTERVAL = 5.minutes

    # Maximum time to wait for the scraper backfill to finish before
    # proceeding to the sync step anyway.  The scraper's backfill is
    # resumable, so the next scheduled run will pick up where it left off.
    MAX_WAIT_TIME = 6.hours

    def perform
      league    = ENV.fetch('BACKFILL_LEAGUE', 'CBLOL')
      min_year  = ENV.fetch('BACKFILL_MIN_YEAR', '2013').to_i
      our_team  = ENV.fetch('BACKFILL_OUR_TEAM', 'paiN Gaming')
      sync_limit = ENV.fetch('BACKFILL_SYNC_LIMIT', '500').to_i

      scraper = ProStaffScraperService.new

      # Step 1: Trigger the backfill on the scraper (returns immediately).
      Rails.logger.info(
        "[HistoricalBackfillJob] Triggering backfill on scraper: " \
        "league=#{league} min_year=#{min_year}"
      )

      begin
        trigger_result = scraper.trigger_historical_backfill(
          league: league,
          min_year: min_year
        )
        Rails.logger.info(
          "[HistoricalBackfillJob] Scraper responded: #{trigger_result.inspect}"
        )
      rescue ProStaffScraperService::ScraperError => e
        Rails.logger.warn(
          "[HistoricalBackfillJob] Scraper trigger failed: #{e.message}. " \
          "Proceeding to sync step (scraper may already be running)."
        )
      end

      # Step 2: Poll backfill status until completion or timeout.
      Rails.logger.info(
        "[HistoricalBackfillJob] Polling backfill status (max #{MAX_WAIT_TIME / 60}min)..."
      )

      started_at = Time.current
      last_status = nil

      loop do
        elapsed = Time.current - started_at
        if elapsed > MAX_WAIT_TIME
          Rails.logger.warn(
            "[HistoricalBackfillJob] Max wait time exceeded (#{MAX_WAIT_TIME / 3600}h). " \
            "Proceeding to sync step. Last status: #{last_status&.inspect}"
          )
          break
        end

        begin
          last_status = scraper.historical_backfill_status(league: league)
          remaining = last_status['remaining'] || 0
          completed = last_status['completed'] || 0
          total     = last_status['total_tournaments'] || 0

          Rails.logger.info(
            "[HistoricalBackfillJob] Progress: #{completed}/#{total} tournaments " \
            "(#{remaining} remaining)"
          )

          # If nothing is pending/in-progress, the backfill is done.
          break if remaining == 0
        rescue ProStaffScraperService::ScraperError => e
          Rails.logger.warn(
            "[HistoricalBackfillJob] Status poll failed: #{e.message}"
          )
        end

        sleep POLL_INTERVAL
      end

      # Step 3: Sync matches from ES into Rails DB for all organizations.
      Rails.logger.info(
        "[HistoricalBackfillJob] Starting sync step: " \
        "league=#{league} our_team=#{our_team} limit=#{sync_limit}"
      )

      Organization.find_each do |org|
        Rails.logger.info(
          "[HistoricalBackfillJob] Syncing for org=#{org.id} (#{org.name})"
        )
        SyncScraperMatchesJob.perform_later(
          org.id,
          league: league,
          our_team: our_team,
          limit: sync_limit
        )
      end

      record_job_heartbeat

      Rails.logger.info("[HistoricalBackfillJob] Done.")
    end
  end
end
