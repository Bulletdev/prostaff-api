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
                                      .includes(:opponent_team, :organization)
                                      .ordered_by_date
                                      .page(params[:page] || 1)
                                      .per(params[:per_page] || 20)

        # Apply filters
        matches = apply_filters(matches)

        render json: {
          message: 'Professional matches retrieved successfully',
          data: {
            matches: ProMatchSerializer.render_as_hash(matches),
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
            match: ProMatchSerializer.render_as_hash(match)
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
      def upcoming
        league   = params[:league]
        per_page = params[:per_page]&.to_i || 20
        page     = params[:page]&.to_i     || 1

        result = @pandascore_service.fetch_upcoming_matches(league: league, per_page: per_page, page: page)

        total_pages = build_total_pages(result, page)

        render json: {
          data: {
            matches: result[:data],
            pagination: pagination_for(result, total_pages),
            source: 'pandascore',
            cached: true
          }
        }
      rescue PandascoreService::RateLimitError => e
        Rails.logger.warn "[ProMatches#upcoming] Rate limit: #{e.message}"
        render json: { error: { code: 'PANDASCORE_RATE_LIMITED', message: e.message } }, status: :too_many_requests
      rescue PandascoreService::PandascoreError => e
        Rails.logger.error "[ProMatches#upcoming] #{e.class}: #{e.message}"
        render json: { error: { code: 'PANDASCORE_ERROR', message: e.message } }, status: :service_unavailable
      end

      # GET /api/v1/competitive/pro-matches/past
      def past
        league   = params[:league]
        per_page = params[:per_page]&.to_i || 20
        page     = params[:page]&.to_i     || 1

        result = @pandascore_service.fetch_past_matches(league: league, per_page: per_page, page: page)
        total_pages = build_total_pages(result, page)

        render json: {
          data: {
            matches: result[:data],
            pagination: pagination_for(result, total_pages),
            source: 'pandascore',
            cached: true
          }
        }
      rescue PandascoreService::RateLimitError => e
        Rails.logger.warn "[ProMatches#past] Rate limit: #{e.message}"
        render json: { error: { code: 'PANDASCORE_RATE_LIMITED', message: e.message } }, status: :too_many_requests
      rescue PandascoreService::PandascoreError => e
        Rails.logger.error "[ProMatches#past] #{e.class}: #{e.message}"
        render json: { error: { code: 'PANDASCORE_ERROR', message: e.message } }, status: :service_unavailable
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
        raise ActionController::ParameterMissing, :our_team if our_team.blank?

        limit = params.fetch(:limit, 100).to_i.clamp(1, 500)

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
        raise ActionController::ParameterMissing, :our_team if our_team.blank?

        service = LeaguepediaRecoveryService.new(current_organization)
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
        raise ActionController::ParameterMissing, :our_team if our_team.blank?

        stage = params[:stage].presence

        service = LeaguepediaRecoveryService.new(current_organization)
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

      # POST /api/v1/competitive/pro-matches/historical-backfill
      # Trigger a full historical backfill: scraper imports from Leaguepedia → ES,
      # then syncs into the Rails DB.  The job runs in the background via Sidekiq.
      #
      # The scraper's backfill is resumable — calling this endpoint multiple times
      # is safe and will only process new/failed tournaments.
      #
      # @param league    [String]  optional — league slug (default from env BACKFILL_LEAGUE)
      # @param min_year  [Integer] optional — earliest year (default from env BACKFILL_MIN_YEAR)
      def historical_backfill
        job = HistoricalBackfillJob.perform_later

        scraper = ProStaffScraperService.new
        status = begin
          scraper.historical_backfill_status(league: params.fetch(:league, ENV.fetch('BACKFILL_LEAGUE', 'CBLOL')))
        rescue ProStaffScraperService::ScraperError => e
          { error: e.message }
        end

        render json: {
          message: 'Historical backfill job enqueued',
          data: {
            job_id: job.job_id,
            league: params.fetch(:league, ENV.fetch('BACKFILL_LEAGUE', 'CBLOL')),
            current_status: status
          }
        }, status: :accepted
      end

      # GET /api/v1/competitive/pro-matches/historical-backfill/status
      # Check the current progress of the historical backfill on the scraper.
      def historical_backfill_status
        league = params.fetch(:league, ENV.fetch('BACKFILL_LEAGUE', 'CBLOL'))

        scraper = ProStaffScraperService.new
        status = scraper.historical_backfill_status(league: league)

        render json: {
          message: 'Backfill status retrieved',
          data: status
        }
      rescue ProStaffScraperService::ScraperError => e
        render json: {
          error: { code: 'SCRAPER_ERROR', message: e.message }
        }, status: :service_unavailable
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
            match: ProMatchSerializer.render_as_hash(imported_match)
          }
        }, status: :created
      rescue PandascoreService::NotFoundError
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

      # GET /api/v1/competitive/pro-matches/match-preview
      # Aggregate preview data for a head-to-head matchup between two pro teams.
      # Params: team1_id (integer), team2_id (integer), team1_name (string), team2_name (string)
      def match_preview
        team1_id   = params[:team1_id]
        team2_id   = params[:team2_id]
        team1_name = params[:team1_name].to_s.strip
        team2_name = params[:team2_name].to_s.strip

        if team1_id.blank? || team2_id.blank?
          return render json: {
            error: { code: 'MISSING_PARAMS', message: 'team1_id and team2_id are required' }
          }, status: :unprocessable_entity
        end

        # Fetch PandaScore data in parallel
        t1_data   = Thread.new { @pandascore_service.fetch_team(team1_id) }
        t2_data   = Thread.new { @pandascore_service.fetch_team(team2_id) }
        t1_recent = Thread.new { @pandascore_service.fetch_team_recent_matches(team1_id) }
        t2_recent = Thread.new { @pandascore_service.fetch_team_recent_matches(team2_id) }

        team1_data   = t1_data.value
        team2_data   = t2_data.value
        team1_recent = t1_recent.value
        team2_recent = t2_recent.value

        # H2H stats from Elasticsearch
        must_clauses = [
          {
            bool: {
              should: [
                { bool: { must: [team_clause(team1_name, 'team1'), team_clause(team2_name, 'team2')] } },
                { bool: { must: [team_clause(team2_name, 'team1'), team_clause(team1_name, 'team2')] } }
              ],
              minimum_should_match: 1
            }
          }
        ]

        es_body = {
          query: { bool: { must: must_clauses } },
          size: 0,
          aggs: {
            team1_wins: { filter: win_team_clause(team1_name) },
            team2_wins: { filter: win_team_clause(team2_name) }
          }
        }

        es_result    = ElasticsearchClient.new.search(index: 'lol_pro_matches', body: es_body)
        h2h_wins_t1  = es_result.dig('aggregations', 'team1_wins', 'doc_count') || 0
        h2h_wins_t2  = es_result.dig('aggregations', 'team2_wins', 'doc_count') || 0

        render json: {
          data: {
            team1: serialize_team(team1_data, team1_recent),
            team2: serialize_team(team2_data, team2_recent),
            h2h_wins_team1: h2h_wins_t1,
            h2h_wins_team2: h2h_wins_t2,
            h2h_total: h2h_wins_t1 + h2h_wins_t2
          }
        }
      rescue StandardError => e
        Rails.logger.error "[ProMatches#match_preview] #{e.class}: #{e.message}"
        render json: { error: { code: 'MATCH_PREVIEW_ERROR', message: 'Failed to build match preview' } },
               status: :service_unavailable
      end

      # GET /api/v1/competitive/pro-matches/es-series
      # Search Elasticsearch for games between two teams.
      # Params: team1, team2, league (optional), after (ISO date), before (ISO date), limit (default 20)
      def es_series
        team1 = params[:team1].to_s.strip
        team2 = params[:team2].to_s.strip
        limit = (params[:limit] || 5).to_i.clamp(1, 50)

        raise ArgumentError, 'team1 and team2 are required' if team1.blank? || team2.blank?

        must_clauses = [
          {
            bool: {
              should: [
                { bool: { must: [team_clause(team1, 'team1'), team_clause(team2, 'team2')] } },
                { bool: { must: [team_clause(team2, 'team1'), team_clause(team1, 'team2')] } }
              ],
              minimum_should_match: 1
            }
          }
        ]

        if params[:after].present? && params[:before].present?
          must_clauses << {
            range: { start_time: { gte: params[:after], lte: params[:before] } }
          }
        end

        es_body = {
          query: { bool: { must: must_clauses } },
          sort: [{ start_time: { order: 'desc' } }],
          size: limit
        }

        result = ElasticsearchClient.new.search(index: 'lol_pro_matches', body: es_body)
        games  = result.dig('hits', 'hits')&.map { |h| h['_source'] } || []

        render json: { data: { games: games, total: games.size } }
      rescue ArgumentError => e
        render json: { error: { code: 'INVALID_PARAMS', message: e.message } }, status: :unprocessable_entity
      rescue StandardError => e
        Rails.logger.error("[ES Series] #{e.class}: #{e.message}")
        render json: { error: { code: 'ES_ERROR', message: 'Failed to fetch series data' } },
               status: :internal_server_error
      end

      private

      def set_pandascore_service
        @pandascore_service = PandascoreService.instance
      end

      # Builds an ES should clause that matches a team name using:
      # 1. Exact term match (handles perfect name equality)
      # 2. Prefix wildcard on first word, case-insensitive (handles suffix differences
      #    between sources, e.g. PandaScore "RED Academy" vs Leaguepedia "RED Kalunga Academy")
      def team_clause(name, field)
        clauses = [{ term: { "#{field}.name" => name } }]

        # Wildcard only for multi-word names to handle sponsor suffixes (e.g. "FlyQuest NZXT").
        # Uses the full name as prefix to avoid false matches ("Team" would hit "Team WE").
        if name.split.length > 1
          clauses << { wildcard: { "#{field}.name" => { value: "#{name}*", case_insensitive: true } } }
        end

        { bool: { should: clauses, minimum_should_match: 1 } }
      end

      # Matches win_team using the same prefix-wildcard logic as team_clause.
      # Needed because PandaScore names have sponsor suffixes (e.g. "FlyQuest NZXT")
      # while Oracle's Elixir stores the base name ("FlyQuest").
      def win_team_clause(name)
        clauses = [{ term: { win_team: name } }]

        clauses << { wildcard: { win_team: { value: "#{name}*", case_insensitive: true } } } if name.split.length > 1

        { bool: { should: clauses, minimum_should_match: 1 } }
      end

      def apply_filters(matches)
        matches = apply_search(matches)
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

      def apply_search(matches)
        return matches unless params[:search].present?

        term      = ActiveRecord::Base.sanitize_sql_like(params[:search])
        norm_term = ActiveRecord::Base.sanitize_sql_like(normalize_search_term(params[:search]))

        # Search by original term (case-insensitive) OR by normalized term
        # translate() maps special chars (Ø→O, æ→a, etc.) directly in PostgreSQL.
        matches.where(
          'lower(opponent_team_name) LIKE lower(:t) OR lower(our_team_name) LIKE lower(:t) ' \
          'OR lower(tournament_display) LIKE lower(:t) ' \
          'OR translate(lower(opponent_team_name), :from, :to) LIKE :n ' \
          'OR translate(lower(our_team_name), :from, :to) LIKE :n ' \
          'OR translate(lower(tournament_display), :from, :to) LIKE :n',
          t: "%#{term}%",
          n: "%#{norm_term}%",
          from: 'øæåðþ',
          to:   'oaadt'
        )
      end

      def normalize_search_term(term)
        term.downcase
            .tr('øåðþ', 'oadt')
            .gsub('æ', 'ae')
            .gsub('ß', 'ss')
            .unicode_normalize(:nfkd)
            .gsub(/\p{Mn}/, '')
      end

      def build_total_pages(result, page)
        pages = result[:per_page].positive? ? [(result[:total].to_f / result[:per_page]).ceil, 1].max : 1
        result[:data].length >= result[:per_page] ? [pages, page].max : pages
      end

      def pagination_for(result, total_pages)
        {
          current_page: result[:page],
          per_page: result[:per_page],
          total_count: result[:total],
          total_pages: total_pages
        }
      end

      def serialize_team(team_data, recent_matches)
        {
          id: team_data['id'],
          name: team_data['name'],
          acronym: team_data['acronym'],
          image_url: team_data['image_url'],
          players: (team_data['players'] || []).map do |p|
            {
              id: p['id'],
              name: p['name'],
              role: p['role'],
              image_url: p['image_url'],
              nationality: p['nationality']
            }
          end.select { |p| %w[top jun mid adc sup].include?(p[:role]) }
                                               .sort_by { |p| %w[top jun mid adc sup].index(p[:role]) },
          recent: (recent_matches || []).first(5).map { |m| serialize_recent_match(m, team_data['id']) }
        }
      end

      def serialize_recent_match(match, our_team_id) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        opponents  = match['opponents'] || []
        other_side = opponents.find { |o| o.dig('opponent', 'id') != our_team_id }
        result       = (match['results'] || []).find { |r| r['team_id'] == our_team_id }
        other_result = (match['results'] || []).find { |r| r['team_id'] != our_team_id }
        our_score    = result&.dig('score') || 0
        opp_score    = other_result&.dig('score') || 0

        {
          opponent_name: other_side&.dig('opponent', 'name'),
          opponent_acronym: other_side&.dig('opponent', 'acronym'),
          opponent_image_url: other_side&.dig('opponent', 'image_url'),
          won: our_score > opp_score,
          score: "#{our_score}-#{opp_score}",
          date: match['begin_at']&.to_s&.first(10)
        }
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
