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
      # @param player_id [Integer, nil] Optional player ID for individual stats
      # @return [Hash] Performance analytics data
      def calculate_performance_data(player_id: nil)
        data = {
          overview: team_overview,
          win_rate_trend: win_rate_trend,
          performance_by_role: performance_by_role,
          best_performers: best_performers,
          match_type_breakdown: match_type_breakdown
        }

        if player_id
          player = @players.find_by(id: player_id)
          data[:player_stats] = player_statistics(player) if player
        end

        data
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

      # Calculates team overview statistics
      def team_overview
        stats = PlayerMatchStat.where(match: @matches)

        {
          total_matches: @matches.count || 0,
          wins: @matches.victories.count || 0,
          losses: @matches.defeats.count || 0,
          win_rate: calculate_win_rate(@matches),
          avg_game_duration: @matches.average(:game_duration)&.round(0) || 0,
          avg_kda: calculate_avg_kda(stats),
          avg_kills_per_game: stats.average(:kills)&.round(1) || 0,
          avg_deaths_per_game: stats.average(:deaths)&.round(1) || 0,
          avg_assists_per_game: stats.average(:assists)&.round(1) || 0,
          avg_gold_per_game: stats.average(:gold_earned)&.round(0) || 0,
          avg_damage_per_game: stats.average(:damage_dealt_total)&.round(0) || 0,
          avg_vision_score: stats.average(:vision_score)&.round(1) || 0
        }
      rescue StandardError => e
        Rails.logger.error("Error in team_overview: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        {}
      end

      # Calculates win rate trend over time
      def win_rate_trend
        # Convert to array and filter out matches without game_start
        matches_array = @matches.to_a.select { |m| m.game_start.present? }
        return [] if matches_array.empty?

        calculate_win_rate_trend(matches_array, group_by: :week)
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
      def best_performers
        @players.map do |player|
          stats = PlayerMatchStat.where(player: player, match: @matches)
          next if stats.empty?

          {
            player: player_hash(player),
            games: stats.count,
            avg_kda: calculate_avg_kda(stats),
            avg_performance_score: stats.average(:performance_score)&.round(1) || 0,
            mvp_count: stats.joins(:match).where(matches: { victory: true }).count
          }
        end.compact.sort_by { |p| -p[:avg_performance_score] }.take(5)
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

        begin
          stats = PlayerMatchStat.where(player: player, match: @matches)
          return nil if stats.empty?

          total_kills = stats.sum(:kills) || 0
          total_deaths = stats.sum(:deaths) || 0
          total_assists = stats.sum(:assists) || 0
          games_played = stats.count

          return nil if games_played.zero?

          wins = stats.joins(:match).where(matches: { victory: true }).count
          win_rate = games_played.zero? ? 0.0 : (wins.to_f / games_played)

          kda = calculate_kda(total_kills, total_deaths, total_assists)

          total_cs = stats.sum(:cs) || 0
          total_duration = @matches.where(id: stats.pluck(:match_id)).sum(:game_duration) || 0

          # Calculate average damage_share from saved stats
          avg_damage_share = stats.average(:damage_share) || 0.0
          damage_share_percentage = (avg_damage_share * 100).round(1)

          # Calculate average farm share (cs_share) from match data
          farm_share_percentage = calculate_farm_share(stats)

          # Calculate Kill Participation %
          kill_participation = calculate_kill_participation(stats)

          # Calculate Early Game Gold Advantage (estimated from first 15 min gold rate)
          early_gold_diff = calculate_early_gold_advantage(stats, player.role)

          {
            player_id: player.id,
            summoner_name: player.summoner_name,
            games_played: games_played,
            win_rate: win_rate,
            kda: kda,
            cs_per_min: calculate_cs_per_min(total_cs, total_duration),
            gold_per_min: calculate_gold_per_min(stats.sum(:gold_earned) || 0, total_duration),
            vision_score: stats.average(:vision_score)&.round(1) || 0.0,
            damage_share: damage_share_percentage,
            farm_share: farm_share_percentage,
            avg_kills: (total_kills.to_f / games_played).round(1),
            avg_deaths: (total_deaths.to_f / games_played).round(1),
            avg_assists: (total_assists.to_f / games_played).round(1),
            # New Elite Metrics
            kill_participation: kill_participation,
            early_gold_diff: early_gold_diff
          }
        rescue StandardError => e
          Rails.logger.error("Error calculating player statistics: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          nil
        end
      end

      # Calculates average farm share (CS share) across matches
      #
      # @param stats [ActiveRecord::Relation] Player match stats
      # @return [Float] Average farm share percentage
      def calculate_farm_share(stats)
        return 0.0 if stats.empty?

        begin
          # Use a simpler approach: calculate based on CS field if available
          # Otherwise, calculate from minions_killed + jungle_minions_killed
          total_player_cs = stats.sum { |s| s.cs || ((s.minions_killed || 0) + (s.jungle_minions_killed || 0)) }
          return 0.0 if total_player_cs.zero?

          # Get all team CS for the same matches
          match_ids = stats.pluck(:match_id).uniq
          return 0.0 if match_ids.empty?

          # Get player's organization
          player = stats.first&.player
          return 0.0 unless player&.organization_id

          # Calculate total team CS for all matches
          team_stats = PlayerMatchStat.joins(:player, :match)
                                      .where(match_id: match_ids, players: { organization_id: player.organization_id })

          total_team_cs = team_stats.sum { |s| s.cs || ((s.minions_killed || 0) + (s.jungle_minions_killed || 0)) }

          return 0.0 if total_team_cs.zero?

          # Return as percentage
          ((total_player_cs.to_f / total_team_cs) * 100).round(1)
        rescue StandardError => e
          Rails.logger.error("Error calculating farm share: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          0.0
        end
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
      # @param stats [ActiveRecord::Relation] Player match stats
      # @return [Float] Kill participation percentage (0-100)
      def calculate_kill_participation(stats)
        return 0.0 if stats.empty?

        player = stats.first&.player
        return 0.0 unless player&.organization_id

        # Calculate per-match and average
        kp_per_match = []

        stats.each do |stat|
          next unless stat.match

          # Player's participation in this match
          player_kills = stat.kills || 0
          player_assists = stat.assists || 0
          player_participation = player_kills + player_assists

          # Team's total kills in this match (all players from same org)
          team_kills = PlayerMatchStat.joins(:player)
                                      .where(match_id: stat.match_id, players: { organization_id: player.organization_id })
                                      .sum(:kills)

          # Calculate KP% for this match
          if team_kills > 0
            match_kp = (player_participation.to_f / team_kills) * 100
            # Cap at 100% to handle edge cases (internal scrims, etc)
            match_kp = [match_kp, 100.0].min
            kp_per_match << match_kp
          end
        end

        return 0.0 if kp_per_match.empty?

        # Return average KP% across all matches
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
