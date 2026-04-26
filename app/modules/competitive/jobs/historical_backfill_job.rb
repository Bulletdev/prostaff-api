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

    # @param options [Hash] optional — supports :league key.
    #   Handles sidekiq-scheduler kwargs wrapper format for backward compat.
    def perform(options = {})
      opts     = options[:kwargs] || options["kwargs"] || options
      league   = (opts[:league] || opts["league"]).presence || ENV.fetch('BACKFILL_LEAGUE', 'CBLOL')
      min_year   = ENV.fetch('BACKFILL_MIN_YEAR', '2013').to_i
      sync_limit = ENV.fetch('BACKFILL_SYNC_LIMIT', '500').to_i

      scraper = ProStaffScraperService.new

      trigger_backfill(scraper, league, min_year)
      poll_until_complete(scraper, league)
      dispatch_sync_jobs(league, sync_limit)

      record_job_heartbeat
      Rails.logger.info("[HistoricalBackfillJob] Done — league=#{league}")
    end

    private

    def trigger_backfill(scraper, league, min_year)
      Rails.logger.info(
        '[HistoricalBackfillJob] Triggering backfill on scraper: ' \
        "league=#{league} min_year=#{min_year}"
      )
      result = scraper.trigger_historical_backfill(league: league, min_year: min_year)
      Rails.logger.info("[HistoricalBackfillJob] Scraper responded: #{result.inspect}")
    rescue ProStaffScraperService::ScraperError => e
      Rails.logger.warn(
        "[HistoricalBackfillJob] Scraper trigger failed: #{e.message}. " \
        'Proceeding to sync step (scraper may already be running).'
      )
    end

    def poll_until_complete(scraper, league)
      Rails.logger.info(
        "[HistoricalBackfillJob] Polling backfill status (max #{MAX_WAIT_TIME / 60}min)..."
      )
      started_at  = Time.current
      last_status = nil

      loop do
        break if Time.current - started_at > MAX_WAIT_TIME && log_timeout_warning(last_status)

        last_status = fetch_backfill_status(scraper, league)
        break if last_status && (last_status['remaining'] || 0).zero?

        sleep POLL_INTERVAL
      end
    end

    def fetch_backfill_status(scraper, league)
      status    = scraper.historical_backfill_status(league: league)
      remaining = status['remaining'] || 0
      completed = status['completed'] || 0
      total     = status['total_tournaments'] || 0
      Rails.logger.info(
        "[HistoricalBackfillJob] Progress: #{completed}/#{total} tournaments " \
        "(#{remaining} remaining)"
      )
      status
    rescue ProStaffScraperService::ScraperError => e
      Rails.logger.warn("[HistoricalBackfillJob] Status poll failed: #{e.message}")
      nil
    end

    def log_timeout_warning(last_status)
      Rails.logger.warn(
        "[HistoricalBackfillJob] Max wait time exceeded (#{MAX_WAIT_TIME / 3600}h). " \
        "Proceeding to sync step. Last status: #{last_status&.inspect}"
      )
      true
    end

    def dispatch_sync_jobs(league, sync_limit)
      Rails.logger.info("[HistoricalBackfillJob] Starting sync step: league=#{league} limit=#{sync_limit}")
      Organization.where.not(competitive_team_name: [nil, '']).find_each do |org|
        Rails.logger.info(
          "[HistoricalBackfillJob] Syncing org=#{org.id} (#{org.name}) team=#{org.competitive_team_name}"
        )
        SyncScraperMatchesJob.perform_later(
          org.id,
          league: league,
          our_team: org.competitive_team_name,
          limit: sync_limit
        )
      end
    end
  end
end
