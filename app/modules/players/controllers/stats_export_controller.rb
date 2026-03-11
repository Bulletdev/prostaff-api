# frozen_string_literal: true

require 'csv'

module Players
  module Controllers
    # Stats Export Controller
    #
    # Exports a player's match stats history as JSON or CSV.
    # Supports date range filtering.
    #
    # @example
    #   GET /api/v1/players/:id/stats/export
    #   GET /api/v1/players/:id/stats/export?format=csv&from=2026-01-01&to=2026-03-06
    class StatsExportController < Api::V1::BaseController
      EXPORT_FIELDS = %w[
        match_date patch_version opponent champion role
        kills deaths assists kda_display cs cs_at_10 cs_per_min
        neutral_minions_killed gold_earned gold_per_min
        damage_dealt_total damage_to_turrets turret_plates_destroyed
        objectives_stolen crowd_control_score total_time_dead
        vision_score wards_placed wards_destroyed
        damage_shielded_teammates healing_to_teammates
        spell_q_casts spell_w_casts spell_e_casts spell_r_casts
        double_kills triple_kills quadra_kills penta_kills
        performance_score result
      ].freeze

      def show
        player = organization_scoped(Player).find(params[:player_id])
        stats  = filtered_stats(player)

        respond_to do |format|
          format.json { render_json_export(player, stats) }
          format.csv  { render_csv_export(player, stats) }
          format.any  { render_json_export(player, stats) }
        end
      end

      private

      def filtered_stats(player)
        scope = PlayerMatchStat.where(player: player)
                               .joins(:match)
                               .includes(:match)
                               .order('matches.game_start DESC')
        scope = scope.where('matches.game_start >= ?', Date.parse(params[:from])) if params[:from].present?
        scope = scope.where('matches.game_start <= ?', Date.parse(params[:to]).end_of_day) if params[:to].present?
        scope
      end

      def render_json_export(player, stats)
        render_success({
                         player: PlayerSerializer.render_as_hash(player),
                         total_games: stats.count,
                         stats: stats.map { |s| build_row_hash(s) }
                       })
      end

      def render_csv_export(player, stats)
        csv_data = build_csv(stats)
        filename = "#{player.summoner_name}_stats_#{Date.current}.csv"

        send_data csv_data,
                  type: 'text/csv; charset=utf-8',
                  disposition: "attachment; filename=\"#{filename}\""
      end

      def build_csv(stats)
        CSV.generate(headers: true) do |csv|
          csv << EXPORT_FIELDS
          stats.each { |s| csv << build_row_array(s) }
        end
      end

      def build_row_hash(stat)
        EXPORT_FIELDS.each_with_object({}) do |field, hash|
          hash[field] = export_field_value(stat, field)
        end
      end

      def build_row_array(stat)
        EXPORT_FIELDS.map { |field| export_field_value(stat, field) }
      end

      def export_field_value(stat, field)
        case field
        when 'match_date'   then stat.match&.game_start&.strftime('%Y-%m-%d')
        when 'patch_version' then stat.match&.patch_version
        when 'opponent'     then stat.match&.opponent_name
        when 'result'       then stat.match&.victory? ? 'W' : 'L'
        when 'kda_display'  then stat.kda_display
        when 'cs_per_min'   then stat.cs_per_min&.round(2)
        when 'gold_per_min' then stat.gold_per_min&.round(0)
        else stat.public_send(field)
        end
      end
    end
  end
end
