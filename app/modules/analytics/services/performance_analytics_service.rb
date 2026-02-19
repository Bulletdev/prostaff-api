# frozen_string_literal: true

module Analytics
  module Services
    # Service for calculating performance analytics
    #
    # Extracts complex analytics calculations from PerformanceController
    # to follow Single Responsibility Principle and reduce controller complexity.
    #
    # @example Calculate performance for matches
    #   service = PerformanceAnalyticsService.new(matches, players)
    #   data = service.calculate_performance_data(player_id: 123)
    #
    class PerformanceAnalyticsService
      include ::Analytics::Concerns::AnalyticsCalculations

      attr_reader :matches, :players

      def initialize(matches, players)
        @matches = matches
        @players = players
      end

      # Calculates complete performance data
      #
      # When player_id is provided, skips all team-level aggregations (overview,
      # trends, role breakdown, best performers) since the frontend only uses
      # player_stats in that context. This avoids 15+ unnecessary DB queries
      # per player-specific request.
      #
      # @param player_id [Integer, nil] Optional player ID for individual stats
      # @param all_players [ActiveRecord::Relation, nil] Scope to resolve the individual player
      #   from. Defaults to @players (active only). Pass the full org scope when you want to
      #   allow individual stats for inactive/bench/trial players too.
      # @return [Hash] Performance analytics data
      def calculate_performance_data(player_id: nil, all_players: nil)
        if player_id
          # Use the broader scope when provided so bench/trial players can still be looked up
          lookup_scope = all_players || @players
          player = lookup_scope.find_by(id: player_id)
          return {
            overview: {},
            win_rate_trend: [],
            performance_by_role: [],
            best_performers: [],
            match_type_breakdown: [],
            player_stats: player ? player_statistics(player) : nil
          }
        end

        {
          overview: team_overview,
          win_rate_trend: win_rate_trend,
          performance_by_role: performance_by_role,
          best_performers: best_performers,
          match_type_breakdown: match_type_breakdown
        }
      rescue StandardError => e
        Rails.logger.error("Error in calculate_performance_data: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        {
          overview: {},
          win_rate_trend: [],
          performance_by_role: [],
          best_performers: [],
          match_type_breakdown: []
        }
      end

      private

      # Calculates team overview statistics using 2 aggregated SQL queries
      # instead of 10+ individual ones.
      def team_overview
        build_team_overview_hash
      rescue StandardError => e
        log_error("team_overview", e)
        {}
      end

      def build_team_overview_hash
        # Query 1: all match-level aggregates in a single pass
        match_row = @matches
          .select(
            'COUNT(*) AS total',
            'COUNT(*) FILTER (WHERE victory) AS wins',
            'COUNT(*) FILTER (WHERE NOT victory) AS losses',
            'ROUND(AVG(game_duration)) AS avg_duration'
          )
          .take

        total  = match_row&.total.to_i
        wins   = match_row&.wins.to_i
        losses = match_row&.losses.to_i
        win_rate = total.zero? ? 0.0 : ((wins.to_f / total) * 100).round(1)

        # Query 2: all stat-level aggregates in a single pass, including sums for KDA
        stat_row = PlayerMatchStat
          .where(match: @matches)
          .select(
            'AVG(kills)               AS avg_kills',
            'AVG(deaths)              AS avg_deaths',
            'AVG(assists)             AS avg_assists',
            'AVG(gold_earned)         AS avg_gold',
            'AVG(damage_dealt_total)  AS avg_damage',
            'AVG(vision_score)        AS avg_vision',
            'SUM(kills)               AS total_kills',
            'SUM(deaths)              AS total_deaths',
            'SUM(assists)             AS total_assists'
          )
          .take

        total_kills   = stat_row&.total_kills.to_i
        total_deaths  = stat_row&.total_deaths.to_i
        total_assists = stat_row&.total_assists.to_i
        deaths_divisor = total_deaths.zero? ? 1 : total_deaths
        avg_kda = ((total_kills + total_assists).to_f / deaths_divisor).round(2)

        {
          total_matches:        total,
          wins:                 wins,
          losses:               losses,
          win_rate:             win_rate,
          avg_game_duration:    match_row&.avg_duration.to_i,
          avg_kda:              avg_kda,
          avg_kills_per_game:   stat_row&.avg_kills.to_f.round(1),
          avg_deaths_per_game:  stat_row&.avg_deaths.to_f.round(1),
          avg_assists_per_game: stat_row&.avg_assists.to_f.round(1),
          avg_gold_per_game:    stat_row&.avg_gold.to_f.round(0),
          avg_damage_per_game:  stat_row&.avg_damage.to_f.round(0),
          avg_vision_score:     stat_row&.avg_vision.to_f.round(1)
        }
      end

      # Calculates win rate trend over time using a single SQL GROUP BY query.
      # DATE_TRUNC groups by ISO week in the DB, avoiding loading all rows into Ruby.
      def win_rate_trend
        return [] if @matches.none?

        rows = @matches
          .where.not(game_start: nil)
          .group("DATE_TRUNC('week', game_start)")
          .select(
            "DATE_TRUNC('week', game_start) AS week",
            'COUNT(*) AS total',
            'SUM(CASE WHEN victory THEN 1 ELSE 0 END) AS wins'
          )

        rows.map do |row|
          total = row.total.to_i
          wins  = row.wins.to_i
          win_rate = total.zero? ? 0.0 : ((wins.to_f / total) * 100).round(1)

          {
            period:   row.week.strftime('%Y-%m-%d'),
            matches:  total,
            wins:     wins,
            losses:   total - wins,
            win_rate: win_rate
          }
        end.sort_by { |d| d[:period] }
      rescue StandardError => e
        Rails.logger.error("Error in win_rate_trend: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        []
      end

      # Calculates performance statistics grouped by role
      def performance_by_role
        stats = PlayerMatchStat.joins(:player).where(match: @matches)

        stats.group('players.role').select(
          'players.role',
          'COUNT(*) as games',
          'AVG(player_match_stats.kills) as avg_kills',
          'AVG(player_match_stats.deaths) as avg_deaths',
          'AVG(player_match_stats.assists) as avg_assists',
          'AVG(player_match_stats.gold_earned) as avg_gold',
          'AVG(player_match_stats.damage_dealt_total) as avg_damage',
          'AVG(player_match_stats.vision_score) as avg_vision'
        ).map do |stat|
          {
            role: stat.role,
            games: stat.games,
            avg_kda: build_kda_hash(stat),
            avg_gold: stat.avg_gold&.round(0) || 0,
            avg_damage: stat.avg_damage&.round(0) || 0,
            avg_vision: stat.avg_vision&.round(1) || 0
          }
        end
      rescue StandardError => e
        Rails.logger.error("Error in performance_by_role: #{e.message}")
        []
      end

      # Identifies top performing players
      # Single GROUP BY query instead of 1+6N per-player queries.
      # Uses subqueries instead of pluck to avoid loading hundreds of IDs into Ruby.
      def best_performers
        return [] if @players.none? || @matches.none?

        aggregated = PlayerMatchStat
          .joins(:match)
          .where(player_id: @players.select(:id), match_id: @matches.select(:id))
          .group(:player_id)
          .select(
            'player_id',
            'COUNT(*) AS games',
            'SUM(kills) AS total_kills',
            'SUM(deaths) AS total_deaths',
            'SUM(assists) AS total_assists',
            'AVG(performance_score) AS avg_performance_score',
            'SUM(CASE WHEN matches.victory THEN 1 ELSE 0 END) AS mvp_count'
          )

        stats_by_player = aggregated.index_by(&:player_id)
        players_by_id   = @players.index_by(&:id)

        stats_by_player.filter_map do |pid, agg|
          player = players_by_id[pid]
          next unless player

          deaths = agg.total_deaths.to_i.zero? ? 1 : agg.total_deaths.to_i
          kda    = ((agg.total_kills.to_i + agg.total_assists.to_i).to_f / deaths).round(2)

          {
            player:                player_hash(player),
            games:                 agg.games.to_i,
            avg_kda:               kda,
            avg_performance_score: agg.avg_performance_score.to_f.round(1),
            mvp_count:             agg.mvp_count.to_i
          }
        end.sort_by { |p| -p[:avg_performance_score] }.take(5)
      rescue StandardError => e
        Rails.logger.error("Error in best_performers: #{e.message}")
        []
      end

      # Calculates match statistics grouped by match type
      def match_type_breakdown
        @matches.group(:match_type).select(
          'match_type',
          'COUNT(*) as total',
          'SUM(CASE WHEN victory THEN 1 ELSE 0 END) as wins'
        ).map do |stat|
          total = stat.total.to_i
          wins = stat.wins.to_i
          win_rate = total.zero? ? 0.0 : ((wins.to_f / total) * 100).round(1)

          {
            match_type: stat.match_type,
            total: total,
            wins: wins,
            losses: total - wins,
            win_rate: win_rate
          }
        end
      rescue StandardError => e
        Rails.logger.error("Error in match_type_breakdown: #{e.message}")
        []
      end

      # Calculates individual player statistics
      #
      # @param player [Player] The player to calculate stats for
      # @return [Hash, nil] Player statistics or nil if no data
      def player_statistics(player)
        return nil unless player.present?

        stats = PlayerMatchStat.where(player: player, match: @matches)
        return nil if stats.empty?

        build_player_statistics_hash(player, stats)
      rescue StandardError => e
        log_error("player statistics", e)
        nil
      end

      def build_player_statistics_hash(player, stats)
        basic_stats = calculate_basic_player_stats(stats)
        return nil if basic_stats[:games_played].zero?

        advanced_metrics = calculate_advanced_player_metrics(stats, player)

        basic_stats.merge(advanced_metrics).merge(
          player_id: player.id,
          summoner_name: player.summoner_name
        )
      end

      def calculate_basic_player_stats(stats)
        total_kills = stats.sum(:kills) || 0
        total_deaths = stats.sum(:deaths) || 0
        total_assists = stats.sum(:assists) || 0
        games_played = stats.count
        wins = stats.joins(:match).where(matches: { victory: true }).count

        {
          games_played: games_played,
          win_rate: games_played.zero? ? 0.0 : (wins.to_f / games_played),
          kda: calculate_kda(total_kills, total_deaths, total_assists),
          avg_kills: (total_kills.to_f / games_played).round(1),
          avg_deaths: (total_deaths.to_f / games_played).round(1),
          avg_assists: (total_assists.to_f / games_played).round(1),
          total_kills: total_kills,
          total_deaths: total_deaths,
          total_assists: total_assists
        }
      end

      def calculate_advanced_player_metrics(stats, player)
        total_cs = stats.sum(:cs) || 0
        total_duration = @matches.where(id: stats.pluck(:match_id)).sum(:game_duration) || 0
        avg_damage_share = stats.average(:damage_share) || 0.0

        {
          cs_per_min: calculate_cs_per_min(total_cs, total_duration),
          gold_per_min: calculate_gold_per_min(stats.sum(:gold_earned) || 0, total_duration),
          vision_score: stats.average(:vision_score)&.round(1) || 0.0,
          damage_share: (avg_damage_share * 100).round(1),
          farm_share: calculate_farm_share(stats),
          kill_participation: calculate_kill_participation(stats),
          early_gold_diff: calculate_early_gold_advantage(stats, player.role)
        }
      end

      # Calculates average farm share (CS share) across matches
      #
      # @param stats [ActiveRecord::Relation] Player match stats
      # @return [Float] Average farm share percentage
      def calculate_farm_share(stats)
        return 0.0 if stats.empty?

        total_player_cs = sum_player_cs(stats)
        return 0.0 if total_player_cs.zero?

        total_team_cs = calculate_team_cs(stats)
        return 0.0 if total_team_cs.zero?

        ((total_player_cs.to_f / total_team_cs) * 100).round(1)
      rescue StandardError => e
        log_error("farm share", e)
        0.0
      end

      def sum_player_cs(stats)
        stats.sum("COALESCE(cs, 0)").to_i
      end

      def calculate_team_cs(stats)
        player = stats.first&.player
        return 0 unless player&.organization_id

        PlayerMatchStat
          .joins(:player)
          .where(match_id: stats.select(:match_id), players: { organization_id: player.organization_id })
          .sum("COALESCE(cs, 0)")
          .to_i
      end

      def log_error(context, error)
        Rails.logger.error("Error in #{context}: #{error.message}")
        Rails.logger.error(error.backtrace.join("\n"))
      end

      # Helper to build KDA hash from stat object
      def build_kda_hash(stat)
        {
          kills: stat.avg_kills&.round(1) || 0,
          deaths: stat.avg_deaths&.round(1) || 0,
          assists: stat.avg_assists&.round(1) || 0
        }
      end

      # Helper to serialize player to hash
      def player_hash(player)
        PlayerSerializer.render_as_hash(player)
      end

      # Calculate Kill Participation % (KP%)
      #
      # Measures what % of team kills the player participated in (kills + assists)
      # High KP% = Player is present in most team fights (good synergy/map awareness)
      #
      # Uses 2 GROUP BY queries instead of one per match to avoid N+1.
      #
      # @param stats [ActiveRecord::Relation] Player match stats
      # @return [Float] Kill participation percentage (0-100)
      def calculate_kill_participation(stats)
        return 0.0 if stats.empty?

        player = stats.first&.player
        return 0.0 unless player&.organization_id

        match_ids = stats.pluck(:match_id)
        return 0.0 if match_ids.empty?

        # Query 1: player's kills+assists per match (from the already-scoped stats relation)
        player_participation_by_match = stats
          .group(:match_id)
          .select('match_id, SUM(kills + assists) AS participation')
          .each_with_object({}) { |r, h| h[r.match_id] = r.participation.to_i }

        # Query 2: team's total kills per match (all players from same org)
        team_kills_by_match = PlayerMatchStat
          .joins(:player)
          .where(match_id: match_ids, players: { organization_id: player.organization_id })
          .group(:match_id)
          .sum(:kills)

        kp_per_match = match_ids.filter_map do |mid|
          team_kills = team_kills_by_match[mid].to_i
          next if team_kills.zero?

          participation = player_participation_by_match[mid].to_i
          match_kp = [(participation.to_f / team_kills) * 100, 100.0].min
          match_kp
        end

        return 0.0 if kp_per_match.empty?

        (kp_per_match.sum / kp_per_match.size).round(1)
      rescue StandardError => e
        Rails.logger.error("Error calculating kill participation: #{e.message}")
        0.0
      end

      # Calculate Early Game Gold Advantage (GD@15 approximation)
      #
      # Since we don't have timeline data, we use a more conservative approach:
      # - Compare player's gold/min to role average gold/min
      # - Scale difference to 15 minutes
      # - This gives relative lane dominance vs average
      #
      # @param stats [ActiveRecord::Relation] Player match stats
      # @param role [String] Player's role
      # @return [Integer] Estimated gold difference at 15 minutes
      def calculate_early_gold_advantage(stats, role)
        return 0 if stats.empty?

        # Calculate player's average gold per minute
        total_gold = stats.sum(:gold_earned) || 0
        total_duration = stats.joins(:match).sum('matches.game_duration') || 0

        return 0 if total_duration.zero?

        player_gold_per_min = (total_gold.to_f / (total_duration / 60.0))

        # Role-based average gold/min benchmarks (from typical pro games)
        # These represent average player performance across full game
        role_avg_gpm = {
          'top' => 420,
          'jungle' => 390,
          'mid' => 430,
          'adc' => 450,
          'support' => 290
        }

        avg_gpm = role_avg_gpm[role&.downcase] || 400

        # Calculate difference in gold/min
        gpm_diff = player_gold_per_min - avg_gpm

        # Scale to 15 minutes for early game representation
        # Use a 0.4 multiplier for more conservative estimate
        early_gold_diff = (gpm_diff * 15 * 0.4).round(0)

        # Cap at reasonable values (-600 to +600)
        [[early_gold_diff, 600].min, -600].max
      rescue StandardError => e
        Rails.logger.error("Error calculating early gold advantage: #{e.message}")
        0
      end
    end
  end
end
