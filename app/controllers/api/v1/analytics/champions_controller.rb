# frozen_string_literal: true

module Api
  module V1
    module Analytics
      # Champion Analytics Controller
      #
      # Provides detailed champion performance statistics for individual players.
      # Analyzes champion pool diversity, mastery levels, and win rates across all champions played.
      #
      # @example GET /api/v1/analytics/champions/:player_id
      #   {
      #     player: { id: 1, name: "Player1" },
      #     champion_stats: [{ champion: "Aatrox", games_played: 15, win_rate: 0.6, avg_kda: 3.2, mastery_grade: "A" }],
      #     champion_diversity: { total_champions: 25, highly_played: 5, average_games: 3.2 }
      #   }
      #
      # Main endpoints:
      # - GET show: Returns comprehensive champion statistics including mastery grades and diversity metrics
      class ChampionsController < Api::V1::BaseController
        def show
          player = organization_scoped(Player).find(params[:player_id])
          stats = fetch_champion_stats(player)
          champion_stats = build_champion_stats(stats)

          render_success(build_champion_data(player, champion_stats))
        end

        def details
          player = organization_scoped(Player).find(params[:player_id])
          champion = params[:champion]

          if champion.blank?
            return render_error(message: 'Champion name is required', code: 'CHAMPION_REQUIRED',
                                status: :bad_request)
          end

          matches = fetch_champion_matches(player, champion)

          if matches.empty?
            return render_error(message: "No matches found for champion #{champion}", code: 'NO_MATCHES',
                                status: :not_found)
          end

          riot_service = RiotCdnService.new
          matches_array = matches.to_a

          render_success({
                           player: PlayerSerializer.render_as_hash(player),
                           champion: champion,
                           icon_url: riot_service.champion_icon_url(champion),
                           aggregate_stats: build_aggregate_stats(matches, matches_array),
                           matches: serialize_champion_matches(matches_array, riot_service)
                         })
        rescue ActiveRecord::RecordNotFound
          render_error(message: 'Player not found', code: 'PLAYER_NOT_FOUND', status: :not_found)
        rescue StandardError => e
          Rails.logger.error("Error in champions#details: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          render_error(message: "Failed to load champion details: #{e.message}", code: 'INTERNAL_ERROR',
                       status: :internal_server_error)
        end

        private

        def fetch_champion_matches(player, champion)
          PlayerMatchStat.where(player: player)
                         .where('LOWER(champion) = ?', champion.downcase)
                         .joins(:match)
                         .includes(:match)
                         .order('matches.game_start DESC')
                         .limit(params[:limit] || 20)
        end

        def build_aggregate_stats(matches, matches_array)
          total_kills = matches_array.sum(&:kills)
          total_deaths = matches_array.sum(&:deaths)
          total_assists = matches_array.sum(&:assists)
          avg_kda = if matches_array.any?
                      ((total_kills + total_assists).to_f / [total_deaths, 1].max).round(2)
                    else
                      0
                    end
          wins = matches_array.count { |m| m.match&.victory? }

          {
            total_games: matches_array.count,
            wins: wins,
            losses: matches_array.count - wins,
            win_rate: matches_array.any? ? (wins.to_f / matches_array.count) : 0,
            avg_kda: avg_kda,
            avg_kills: matches_array.sum(&:kills).to_f / [matches_array.count, 1].max,
            avg_deaths: matches_array.sum(&:deaths).to_f / [matches_array.count, 1].max,
            avg_assists: matches_array.sum(&:assists).to_f / [matches_array.count, 1].max,
            avg_cs_per_min: matches.average(:cs_per_min)&.round(1) || 0,
            avg_damage_dealt: matches.average(:damage_dealt_total)&.round(0) || 0,
            avg_damage_taken: matches.average(:damage_taken)&.round(0) || 0,
            avg_gold_per_min: matches.average(:gold_per_min)&.round(0) || 0,
            avg_vision_score: matches.average(:vision_score)&.round(1) || 0
          }
        end

        def serialize_champion_matches(matches_array, riot_service)
          matches_array.filter_map do |stat|
            next nil unless stat.match

            build_match_entry(stat, riot_service)
          end
        end

        def build_match_entry(stat, riot_service)
          {
            match_id: stat.match.id,
            game_id: stat.match.riot_match_id,
            date: stat.match.game_start&.strftime('%Y-%m-%d %H:%M'),
            victory: stat.match.victory?,
            game_duration: stat.match.game_duration || 0,
            kda: stat.kda_display,
            kda_ratio: (stat.kda_ratio || 0).round(2),
            kills: stat.kills || 0,
            deaths: stat.deaths || 0,
            assists: stat.assists || 0,
            cs: stat.cs || 0,
            cs_per_min: (stat.cs_per_min || 0).round(1),
            damage_dealt: stat.damage_dealt_total || 0,
            damage_taken: stat.damage_taken || 0,
            gold_earned: stat.gold_earned || 0,
            gold_per_min: (stat.gold_per_min || 0).round(0),
            vision_score: stat.vision_score || 0,
            performance_score: stat.performance_score || 0,
            kill_participation: stat.kill_participation || 0,
            damage_share: stat.damage_share || 0,
            gold_share: stat.gold_share || 0,
            wards_placed: stat.wards_placed || 0,
            wards_destroyed: stat.wards_destroyed || 0,
            control_wards: stat.control_wards_purchased || 0,
            healing_done: stat.healing_done || 0,
            double_kills: stat.double_kills || 0,
            triple_kills: stat.triple_kills || 0,
            quadra_kills: stat.quadra_kills || 0,
            penta_kills: stat.penta_kills || 0,
            first_blood: stat.first_blood || false,
            first_tower: stat.first_tower || false,
            largest_killing_spree: stat.largest_killing_spree || 0,
            largest_multi_kill: stat.largest_multi_kill || 0,
            items: (stat.items || []).map { |id| { id: id, icon_url: riot_service.item_icon_url(id) } },
            runes: (stat.runes || []).map { |id| { id: id, icon_url: riot_service.rune_icon_url(id) } },
            spells: build_spells(stat, riot_service),
            role: stat.role
          }
        end

        def build_spells(stat, riot_service)
          [
            { name: stat.summoner_spell_1, icon_url: riot_service.spell_icon_url(stat.summoner_spell_1&.to_i) },
            { name: stat.summoner_spell_2, icon_url: riot_service.spell_icon_url(stat.summoner_spell_2&.to_i) }
          ].select { |s| s[:name].present? }
        end

        def fetch_champion_stats(player)
          PlayerMatchStat.where(player: player)
                         .group(:champion)
                         .select(
                           'champion',
                           'COUNT(*) as games_played',
                           'SUM(CASE WHEN matches.victory THEN 1 ELSE 0 END) as wins',
                           'AVG((kills + assists)::float / NULLIF(deaths, 0)) as avg_kda',
                           'AVG(cs_per_min) as avg_cs_per_min',
                           'AVG(damage_dealt_total) as avg_damage_dealt',
                           'AVG(damage_taken) as avg_damage_taken',
                           'AVG(gold_per_min) as avg_gold_per_min',
                           'AVG(vision_score) as avg_vision_score'
                         )
                         .joins(:match)
                         .order('games_played DESC')
        end

        def build_champion_stats(stats)
          riot_service = RiotCdnService.new
          stats.map { |stat| build_champion_stat_hash(stat, riot_service) }
        end

        def build_champion_stat_hash(stat, riot_service)
          win_rate = stat.games_played.zero? ? 0 : (stat.wins.to_f / stat.games_played)
          {
            champion: stat.champion,
            games_played: stat.games_played,
            win_rate: win_rate,
            avg_kda: stat.avg_kda&.round(2) || 0,
            avg_cs_per_min: stat.avg_cs_per_min&.round(1) || 0.0,
            avg_damage_dealt: stat.avg_damage_dealt&.round(0) || 0,
            avg_damage_taken: stat.avg_damage_taken&.round(0) || 0,
            avg_gold_per_min: stat.avg_gold_per_min&.round(0) || 0,
            avg_vision_score: stat.avg_vision_score&.round(1) || 0.0,
            mastery_grade: calculate_mastery_grade(win_rate, stat.avg_kda),
            icon_url: riot_service.champion_icon_url(stat.champion)
          }
        end

        def build_champion_data(player, champion_stats)
          {
            player: PlayerSerializer.render_as_hash(player),
            champion_stats: champion_stats,
            top_champions: champion_stats.take(5),
            champion_diversity: build_champion_diversity(champion_stats)
          }
        end

        def build_champion_diversity(champion_stats)
          {
            total_champions: champion_stats.count,
            highly_played: champion_stats.count { |c| c[:games_played] >= 10 },
            average_games: champion_stats.empty? ? 0 : average_games_per_champion(champion_stats)
          }
        end

        def average_games_per_champion(champion_stats)
          (champion_stats.sum { |c| c[:games_played] } / champion_stats.count.to_f).round(1)
        end

        def calculate_mastery_grade(win_rate, avg_kda)
          score = (win_rate * 100 * 0.6) + ((avg_kda || 0) * 10 * 0.4)

          case score
          when 80..Float::INFINITY then 'S'
          when 70...80 then 'A'
          when 60...70 then 'B'
          when 50...60 then 'C'
          else 'D'
          end
        end
      end
    end
  end
end
