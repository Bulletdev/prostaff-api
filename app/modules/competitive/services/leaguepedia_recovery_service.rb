# frozen_string_literal: true

module Competitive
  module Services
    # Recovers missing competitive match games by querying Leaguepedia Cargo API directly.
    #
    # This service bypasses the ProStaff Scraper microservice entirely, querying
    # Leaguepedia's public Cargo API and importing matches through the existing
    # ScraperImporterService format. Use it when the scraper pipeline missed a game
    # due to rate limits, timeouts, or enrichment failures.
    #
    # Rate limit handling: Leaguepedia enforces ~60 req/min per IP. The service
    # uses exponential backoff on 429/ratelimited responses and caches game data
    # in Redis to avoid duplicate fetches.
    #
    # @example Recover missing CBLOL Cup games for paiN Gaming
    #   service = Competitive::Services::LeaguepediaRecoveryService.new(organization)
    #   result  = service.recover_missing(
    #     overview_page: 'CBLOL/2026 Season/Cup',
    #     our_team: 'paiN Gaming'
    #   )
    #   # => { recovered: 1, already_present: 12, errors: 0, skipped_no_players: 0 }
    #
    class LeaguepediaRecoveryService
      CARGO_BASE_URL = 'https://lol.fandom.com/api.php'
      CACHE_TTL      = 30.minutes
      MAX_RETRIES    = 3
      BACKOFF_BASE   = 2 # seconds — doubles each retry

      SCOREBOARD_GAMES_FIELDS = %w[
        GameId MatchId GameInMatch DateTime_UTC
        Team1 Team2 Winner Patch VOD Gamelength_Number
      ].freeze

      SCOREBOARD_PLAYERS_FIELDS = %w[
        GameId Team Champion Role Player
        Kills Deaths Assists Win
      ].freeze

      # Maps Leaguepedia role strings to our internal convention
      ROLE_MAP = {
        'Top'     => 'top',
        'Jungle'  => 'jungle',
        'Mid'     => 'mid',
        'Bot'     => 'adc',
        'Support' => 'support'
      }.freeze

      def initialize(organization)
        @organization = organization
        @importer     = ScraperImporterService.new(organization)
      end

      # Find and import games that exist in Leaguepedia but not in our DB.
      #
      # @param overview_page [String] Leaguepedia OverviewPage, e.g. 'CBLOL/2026 Season/Cup'
      # @param our_team      [String] Team name filter, e.g. 'paiN Gaming'
      # @param stage         [String] optional — filter to a specific stage
      # @return [Hash] recovery statistics
      def recover_missing(overview_page:, our_team:, stage: nil)
        stats = { recovered: 0, already_present: 0, errors: 0, skipped_no_players: 0 }

        games = fetch_games(overview_page: overview_page, stage: stage)
        Rails.logger.info(
          "[LeaguepediaRecovery] Found #{games.size} games for #{overview_page} " \
          "our_team=#{our_team.inspect}"
        )

        pain_games = games.select do |g|
          teams_match?(g['Team1'], our_team) || teams_match?(g['Team2'], our_team)
        end

        Rails.logger.info("[LeaguepediaRecovery] #{pain_games.size} games involve #{our_team}")

        pain_games.each do |game|
          process_game(game, our_team, stats)
        end

        Rails.logger.info("[LeaguepediaRecovery] Done: #{stats.inspect}")
        stats
      end

      # Diagnose which games are missing for an overview page and team.
      # Returns a list of GameIds found in Leaguepedia but absent from our DB.
      #
      # @param overview_page [String]
      # @param our_team      [String]
      # @return [Array<Hash>] missing game metadata
      def diagnose_missing(overview_page:, our_team:)
        games = fetch_games(overview_page: overview_page)
        pain_games = games.select do |g|
          teams_match?(g['Team1'], our_team) || teams_match?(g['Team2'], our_team)
        end

        pain_games.map do |g|
          game_in_match = g['GameInMatch'].to_i
          ext_id = "#{g['GameId']}_#{game_in_match}"
          present = @organization.competitive_matches.exists?(external_match_id: ext_id)

          {
            game_id: g['GameId'],
            external_match_id: ext_id,
            date: g['DateTime UTC'],
            team1: g['Team1'],
            team2: g['Team2'],
            winner: g['Winner'],
            game_in_match: game_in_match,
            present_in_db: present
          }
        end
      end

      private

      def process_game(game, our_team, stats)
        game_id       = game['GameId']
        game_in_match = game['GameInMatch'].to_i
        ext_id        = "#{game_id}_#{game_in_match}"

        if @organization.competitive_matches.exists?(external_match_id: ext_id)
          stats[:already_present] += 1
          return
        end

        players = fetch_players(game_id: game_id)
        if players.empty?
          Rails.logger.warn "[LeaguepediaRecovery] No players found for game #{game_id} — skipping"
          stats[:skipped_no_players] += 1
          return
        end

        match_doc = build_match_document(game, players, game_id, game_in_match)
        batch_stats = @importer.import_batch([match_doc], our_team: our_team)
        stats[:recovered]   += batch_stats[:imported].to_i
        stats[:errors]      += batch_stats[:errors].to_i

        Rails.logger.info(
          "[LeaguepediaRecovery] game=#{game_id} game_in_match=#{game_in_match} " \
          "result=#{batch_stats.inspect}"
        )
      rescue StandardError => e
        Rails.logger.error "[LeaguepediaRecovery] Error processing #{game_id}: #{e.message}"
        stats[:errors] += 1
      end

      # Fetch all ScoreboardGames rows for the given overview_page.
      def fetch_games(overview_page:, stage: nil)
        cache_key = "leaguepedia_recovery:games:#{overview_page}:#{stage}"
        cached    = Rails.cache.read(cache_key)
        return cached if cached

        where_clause = "OverviewPage=\"#{overview_page}\""
        where_clause += " AND Tournament LIKE \"%#{stage}%\"" if stage.present?

        rows = cargo_query(
          tables: 'ScoreboardGames',
          fields: SCOREBOARD_GAMES_FIELDS.join(','),
          where: where_clause,
          order_by: 'DateTime_UTC',
          limit: 500
        )

        # Only cache non-empty results to avoid caching rate-limited responses
        Rails.cache.write(cache_key, rows, expires_in: CACHE_TTL) if rows.any?
        rows
      end

      # Fetch ScoreboardPlayers rows for a specific GameId.
      def fetch_players(game_id:)
        cache_key = "leaguepedia_recovery:players:#{game_id}"
        cached    = Rails.cache.read(cache_key)
        return cached if cached

        rows = cargo_query(
          tables: 'ScoreboardPlayers',
          fields: SCOREBOARD_PLAYERS_FIELDS.join(','),
          where: "GameId=\"#{game_id}\"",
          order_by: 'Team,Role',
          limit: 10
        )

        # Only cache non-empty results
        Rails.cache.write(cache_key, rows, expires_in: CACHE_TTL) if rows.any?
        rows
      end

      # Build a match document compatible with ScraperImporterService#import_batch.
      def build_match_document(game, players, game_id, game_in_match)
        team1 = game['Team1'].to_s
        team2 = game['Team2'].to_s
        winner = game['Winner'].to_s

        # Derive league and stage from GameId format:
        # "CBLOL/2026 Season/Cup_Play-In Round 1_1_2"
        # overview_page = "CBLOL/2026 Season/Cup"
        # The league is the first segment (e.g. "CBLOL")
        league = game_id.split('/').first.to_s.upcase

        # Stage comes from the segment after the overview page
        stage = extract_stage(game_id)

        {
          'riot_enriched'      => true,
          'enrichment_source'  => 'leaguepedia_direct',
          'leaguepedia_page'   => game['GameId'],
          'match_id'           => game_id,
          'game_number'        => game_in_match,
          'league'             => league,
          'stage'              => stage,
          'start_time'         => game['DateTime UTC'],
          'patch'              => game['Patch'],
          'win_team'           => winner,
          'gamelength'         => game['Gamelength Number'],
          'game_duration_seconds' => parse_gamelength(game['Gamelength Number']),
          'vod_youtube_id'     => extract_youtube_id(game['VOD']),
          'team1'              => { 'name' => team1 },
          'team2'              => { 'name' => team2 },
          'participants'       => build_participants(players)
        }
      end

      def build_participants(players)
        players.map do |p|
          {
            'team_name'    => p['Team'],
            'champion_name' => p['Champion'],
            'role'         => normalize_role(p['Role']),
            'summoner_name' => p['Player'],
            'kills'        => p['Kills'].to_i,
            'deaths'       => p['Deaths'].to_i,
            'assists'      => p['Assists'].to_i,
            'win'          => p['Win'].to_s.downcase == '1' || p['Win'].to_s.downcase == 'yes'
          }
        end
      end

      def normalize_role(role)
        ROLE_MAP[role] || role&.downcase || 'unknown'
      end

      # Extract stage name from GameId like "CBLOL/2026 Season/Cup_Play-In Round 1_1_2"
      def extract_stage(game_id)
        # GameId format: OverviewPage_Stage_MatchNumber_GameNumber
        # e.g. "CBLOL/2026 Season/Cup_Play-In Round 1_1_2"
        # Overview page = "CBLOL/2026 Season/Cup"
        # Remaining: "_Play-In Round 1_1_2" -> stage = "Play-In Round 1"
        parts = game_id.split('_')
        return game_id if parts.size < 2

        # Drop the last two numeric parts (match_num, game_num) and the overview prefix
        # The overview page contains no underscores except when split by '/'
        # GameId = OverviewPage + "_" + Stage + "_" + MatchNumber + "_" + GameNumber
        # Stage may contain spaces but not underscores in most cases
        # We remove the last 2 parts (match number and game number)
        parts.length > 3 ? parts[1..-3].join('_') : parts[1]
      rescue StandardError
        'Unknown'
      end

      # Parse Leaguepedia gamelength (MM:SS) to seconds.
      def parse_gamelength(gamelength)
        return nil if gamelength.blank?

        parts = gamelength.to_s.split(':').map(&:to_i)
        return nil if parts.empty?

        parts[0] * 60 + parts[1].to_i
      rescue StandardError
        nil
      end

      # Extract YouTube video ID from a VOD URL or raw ID.
      def extract_youtube_id(vod)
        return nil if vod.blank?
        return vod if vod.length <= 15 && vod !~ /https?:/

        match = vod.match(/(?:v=|youtu\.be\/)([A-Za-z0-9_-]{11})/)
        match ? match[1] : nil
      end

      # Case-insensitive partial match (mirrors ScraperImporterService).
      def teams_match?(team_name, candidate)
        return false if team_name.blank? || candidate.blank?

        t = team_name.downcase.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '')
        c = candidate.downcase.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '')
        t == c || t.include?(c) || c.include?(t)
      end

      # Execute a Cargo API query with exponential backoff on rate limit.
      def cargo_query(tables:, fields:, where:, order_by:, limit: 100)
        params = {
          action:    'cargoquery',
          format:    'json',
          tables:    tables,
          fields:    fields,
          where:     where,
          order_by:  order_by,
          limit:     limit
        }

        uri = URI(CARGO_BASE_URL)
        uri.query = URI.encode_www_form(params)

        MAX_RETRIES.times do |attempt|
          response = fetch_with_ua(uri)

          case response
          when Net::HTTPSuccess
            data = JSON.parse(response.body)
            if data['error']
              code = data['error']['code']
              if code == 'ratelimited'
                wait = BACKOFF_BASE**attempt
                Rails.logger.warn(
                  "[LeaguepediaRecovery] Rate limited (attempt #{attempt + 1}), " \
                  "waiting #{wait}s..."
                )
                sleep(wait)
                next
              end
              raise StandardError, "Leaguepedia API error: #{data['error']['info']}"
            end
            return data.fetch('cargoquery', []).map { |r| r['title'] }
          else
            raise StandardError, "Leaguepedia HTTP #{response.code}: #{response.message}"
          end
        end

        Rails.logger.error '[LeaguepediaRecovery] Max retries exceeded for Leaguepedia query'
        []
      end

      def fetch_with_ua(uri)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 15) do |http|
          req = Net::HTTP::Get.new(uri)
          req['User-Agent'] = 'ProStaffAnalytics/1.0 (esports data; https://prostaff.gg)'
          req['Accept']     = 'application/json'
          http.request(req)
        end
      end
    end
  end
end
