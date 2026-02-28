# frozen_string_literal: true

module Competitive
  module Controllers
    # Lists and shows professional match results from the competitive scene.
    # Data is sourced from PandaScore and cached in the organization's competitive_matches.
    class ProMatchesController < Api::V1::BaseController
      include Paginatable

      before_action :set_pandascore_service

      # GET /api/v1/competitive/pro-matches
      # List recent professional matches from database
      def index
        matches = current_organization.competitive_matches
                                      .ordered_by_date
                                      .page(params[:page] || 1)
                                      .per(params[:per_page] || 20)

        # Apply filters
        matches = apply_filters(matches)

        render json: {
          message: 'Professional matches retrieved successfully',
          data: {
            matches: ::Competitive::Serializers::ProMatchSerializer.render_as_hash(matches),
            pagination: pagination_meta(matches)
          }
        }
      rescue StandardError => e
        Rails.logger.error "[ProMatches] Error in index: #{e.message}"
        render json: {
          error: {
            code: 'PRO_MATCHES_ERROR',
            message: 'Failed to retrieve matches',
            details: e.message
          }
        }, status: :internal_server_error
      end

      # GET /api/v1/competitive/pro-matches/:id
      # Get details of a specific professional match
      def show
        match = current_organization.competitive_matches.find(params[:id])

        render json: {
          message: 'Match details retrieved successfully',
          data: {
            match: ::Competitive::Serializers::ProMatchSerializer.render_as_hash(match)
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          error: {
            code: 'MATCH_NOT_FOUND',
            message: 'Professional match not found'
          }
        }, status: :not_found
      end

      # GET /api/v1/competitive/pro-matches/upcoming
      # Fetch upcoming matches from PandaScore API
      def upcoming
        league = params[:league]
        per_page = params[:per_page]&.to_i || 10

        matches = @pandascore_service.fetch_upcoming_matches(
          league: league,
          per_page: per_page
        )

        render json: {
          message: 'Upcoming matches retrieved successfully',
          data: {
            matches: matches,
            source: 'pandascore',
            cached: true
          }
        }
      rescue ::Competitive::Services::PandascoreService::PandascoreError => e
        render json: {
          error: {
            code: 'PANDASCORE_ERROR',
            message: e.message
          }
        }, status: :service_unavailable
      end

      # GET /api/v1/competitive/pro-matches/past
      # Fetch past matches from PandaScore API
      def past
        league = params[:league]
        per_page = params[:per_page]&.to_i || 20

        matches = @pandascore_service.fetch_past_matches(
          league: league,
          per_page: per_page
        )

        render json: {
          message: 'Past matches retrieved successfully',
          data: {
            matches: matches,
            source: 'pandascore',
            cached: true
          }
        }
      rescue ::Competitive::Services::PandascoreService::PandascoreError => e
        render json: {
          error: {
            code: 'PANDASCORE_ERROR',
            message: e.message
          }
        }, status: :service_unavailable
      end

      # POST /api/v1/competitive/pro-matches/refresh
      # Force refresh of PandaScore cache (owner only)
      def refresh
        authorize :pro_match, :refresh?

        @pandascore_service.clear_cache

        render json: {
          message: 'Cache cleared successfully',
          data: { cleared_at: Time.current }
        }
      rescue Pundit::NotAuthorizedError
        render json: {
          error: {
            code: 'FORBIDDEN',
            message: 'Only organization owners can refresh cache'
          }
        }, status: :forbidden
      end

      # POST /api/v1/competitive/pro-matches/sync-from-scraper
      # Enqueue a background job to import enriched matches from the ProStaff Scraper.
      #
      # The scraper collects data from LoL Esports (schedules) and Leaguepedia
      # (per-player stats). Only fully enriched matches (riot_enriched=true) are imported.
      # Duplicates are skipped automatically via external_match_id uniqueness.
      #
      # @param league   [String]  required — league slug (e.g. 'CBLOL', 'LCS')
      # @param our_team [String]  required — org's team name exactly as listed in Leaguepedia
      #                           (e.g. 'paiN Gaming'). Without this, ALL tournament games
      #                           would be imported — always required.
      # @param limit    [Integer] optional — max matches to import (default 100)
      def sync_from_scraper
        league   = params.require(:league)
        our_team = params[:our_team].presence
        raise ActionController::ParameterMissing.new(:our_team) if our_team.blank?

        limit    = params.fetch(:limit, 100).to_i.clamp(1, 500)

        job = SyncScraperMatchesJob.perform_later(
          current_organization.id,
          league: league,
          our_team: our_team,
          limit: limit
        )

        render json: {
          message: 'Scraper sync started in background',
          data: {
            job_id: job.job_id,
            league: league,
            our_team: our_team,
            limit: limit
          }
        }, status: :accepted
      rescue ActionController::ParameterMissing => e
        render json: {
          error: { code: 'MISSING_PARAM', message: e.message }
        }, status: :unprocessable_entity
      rescue ProStaffScraperService::UnavailableError => e
        render json: {
          error: { code: 'SCRAPER_UNAVAILABLE', message: e.message }
        }, status: :service_unavailable
      end

      # POST /api/v1/competitive/pro-matches/sync-from-leaguepedia
      # Trigger the Leaguepedia native pipeline on the scraper for a full tournament import.
      #
      # Unlike sync-from-scraper (which fetches already-indexed LoL Esports data),
      # this endpoint queries Leaguepedia ScoreboardGames directly by OverviewPage,
      # allowing import of historical regular-season games that have fallen out of
      # the LoL Esports API's 300-event rolling window.
      #
      # The pipeline runs asynchronously on the scraper. Once it completes, call
      # sync-from-scraper to import the newly indexed docs into the Rails DB.
      #
      # @param tournament [String] required — Leaguepedia OverviewPage
      #                            (e.g. 'CBLOL/2026 Season/Cup')
      # @param our_team   [String] optional — passed through to sync-from-scraper later
      def sync_from_leaguepedia
        tournament = params.require(:tournament)
        our_team   = params[:our_team].presence

        scraper = ProStaffScraperService.new
        result  = scraper.trigger_leaguepedia_sync(tournament: tournament)

        render json: {
          message: 'Leaguepedia pipeline triggered on scraper',
          data: {
            tournament: tournament,
            our_team: our_team,
            scraper: result,
            note: 'Pipeline runs in background. Call sync-from-scraper after it completes to import data into Rails.'
          }
        }, status: :accepted
      rescue ActionController::ParameterMissing => e
        render json: {
          error: { code: 'MISSING_PARAM', message: e.message }
        }, status: :unprocessable_entity
      rescue ProStaffScraperService::UnauthorizedError => e
        render json: {
          error: { code: 'SCRAPER_UNAUTHORIZED', message: e.message }
        }, status: :service_unavailable
      rescue ProStaffScraperService::UnavailableError => e
        render json: {
          error: { code: 'SCRAPER_UNAVAILABLE', message: e.message }
        }, status: :service_unavailable
      end

      # GET /api/v1/competitive/pro-matches/diagnose-missing
      # Cross-reference Leaguepedia Cargo API with our DB to find missing games.
      # Bypasses the ProStaff Scraper — queries Leaguepedia directly.
      #
      # @param overview_page [String] required — Leaguepedia OverviewPage
      # @param our_team      [String] required — team name as in Leaguepedia
      def diagnose_missing
        overview_page = params.require(:overview_page)
        our_team      = params[:our_team].presence
        raise ActionController::ParameterMissing.new(:our_team) if our_team.blank?

        service = ::Competitive::Services::LeaguepediaRecoveryService.new(current_organization)
        games   = service.diagnose_missing(overview_page: overview_page, our_team: our_team)

        missing = games.reject { |g| g[:present_in_db] }
        present = games.select { |g| g[:present_in_db] }

        render json: {
          message: "Diagnosis complete for #{our_team}",
          data: {
            overview_page: overview_page,
            our_team: our_team,
            total_in_leaguepedia: games.size,
            present_in_db: present.size,
            missing_count: missing.size,
            missing_games: missing,
            present_games: present
          }
        }
      rescue ActionController::ParameterMissing => e
        render json: { error: { code: 'MISSING_PARAM', message: e.message } },
               status: :unprocessable_entity
      rescue StandardError => e
        Rails.logger.error "[ProMatches#diagnose_missing] #{e.message}"
        render json: { error: { code: 'LEAGUEPEDIA_ERROR', message: e.message } },
               status: :service_unavailable
      end

      # POST /api/v1/competitive/pro-matches/recover-missing
      # Recover missing games by querying Leaguepedia Cargo API directly.
      # Bypasses the ProStaff Scraper — no SCRAPER_API_KEY required.
      #
      # Flow:
      #   1. Fetch all ScoreboardGames for the overview_page from Leaguepedia
      #   2. Filter to games involving our_team
      #   3. Skip games already present in the DB (by external_match_id)
      #   4. For each missing game, fetch ScoreboardPlayers and import
      #
      # @param overview_page [String] required — Leaguepedia OverviewPage
      # @param our_team      [String] required — team name as in Leaguepedia
      # @param stage         [String] optional — filter to a specific stage
      def recover_missing
        overview_page = params.require(:overview_page)
        our_team      = params[:our_team].presence
        raise ActionController::ParameterMissing.new(:our_team) if our_team.blank?

        stage = params[:stage].presence

        service = ::Competitive::Services::LeaguepediaRecoveryService.new(current_organization)
        result  = service.recover_missing(
          overview_page: overview_page,
          our_team: our_team,
          stage: stage
        )

        render json: {
          message: "Recovery complete for #{our_team} in #{overview_page}",
          data: {
            overview_page: overview_page,
            our_team: our_team,
            stage: stage,
            stats: result
          }
        }, status: :ok
      rescue ActionController::ParameterMissing => e
        render json: { error: { code: 'MISSING_PARAM', message: e.message } },
               status: :unprocessable_entity
      rescue StandardError => e
        Rails.logger.error "[ProMatches#recover_missing] #{e.message}"
        render json: { error: { code: 'LEAGUEPEDIA_ERROR', message: e.message } },
               status: :service_unavailable
      end

      # POST /api/v1/competitive/pro-matches/import
      # Import a match from PandaScore to our database
      def import
        match_id = params[:match_id]
        raise ArgumentError, 'match_id is required' if match_id.blank?

        # Fetch match details from PandaScore
        match_data = @pandascore_service.fetch_match_details(match_id)

        # Import to our database (implement import logic)
        imported_match = import_match_to_database(match_data)

        render json: {
          message: 'Match imported successfully',
          data: {
            match: ::Competitive::Serializers::ProMatchSerializer.render_as_hash(imported_match)
          }
        }, status: :created
      rescue ::Competitive::Services::PandascoreService::NotFoundError
        render json: {
          error: {
            code: 'MATCH_NOT_FOUND',
            message: 'Match not found in PandaScore'
          }
        }, status: :not_found
      rescue ArgumentError => e
        render json: {
          error: {
            code: 'INVALID_PARAMS',
            message: e.message
          }
        }, status: :unprocessable_entity
      end

      private

      def set_pandascore_service
        @pandascore_service = ::Competitive::Services::PandascoreService.instance
      end

      def apply_filters(matches)
        matches = matches.by_tournament(params[:tournament]) if params[:tournament].present?
        matches = matches.by_region(params[:region]) if params[:region].present?
        matches = matches.by_patch(params[:patch]) if params[:patch].present?
        matches = matches.victories if params[:victories_only] == 'true'
        matches = matches.defeats if params[:defeats_only] == 'true'

        if params[:start_date].present? && params[:end_date].present?
          matches = matches.in_date_range(
            Date.parse(params[:start_date]),
            Date.parse(params[:end_date])
          )
        end

        matches
      end

      def import_match_to_database(match_data)
        # TODO: Implement match import logic
        # This would parse PandaScore match data and create a CompetitiveMatch record
        # For now, return a placeholder
        raise NotImplementedError, 'Match import not yet implemented'
      end
    end
  end
end
