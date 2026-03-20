# frozen_string_literal: true

require 'csv'

module Matches
  module Controllers
    # Export Controller
    #
    # Exports match player stats as JSON or CSV.
    # Scoped to the current organization.
    #
    # @example
    #   GET /api/v1/matches/:id/export          -> JSON
    #   GET /api/v1/matches/:id/export?format=csv -> CSV
    class ExportController < Api::V1::BaseController
      skip_before_action :set_default_response_format

      EXPORT_FIELDS = %w[
        player_name champion role kills deaths assists
        cs neutral_minions_killed cs_at_10
        gold_earned damage_dealt_total damage_taken
        damage_to_turrets turret_plates_destroyed
        objectives_stolen crowd_control_score total_time_dead
        vision_score wards_placed wards_destroyed
        damage_shielded_teammates healing_to_teammates
        spell_q_casts spell_w_casts spell_e_casts spell_r_casts
        double_kills triple_kills quadra_kills penta_kills
        performance_score
      ].freeze

      def show
        match = organization_scoped(Match).find(params[:id])
        stats = match.player_match_stats.includes(:player)

        respond_to do |format|
          format.json { render_json_export(match, stats) }
          format.csv  { render_csv_export(match, stats) }
          format.any  { render_json_export(match, stats) }
        end
      end

      private

      def render_json_export(match, stats)
        render_success({
                         match_id: match.id,
                         riot_match_id: match.riot_match_id,
                         game_start: match.game_start,
                         patch_version: match.game_version,
                         players: stats.map { |s| build_row_hash(s) }
                       })
      end

      def render_csv_export(match, stats)
        csv_data = build_csv(stats)
        filename = "match_#{match.riot_match_id || match.id}_#{Date.current}.csv"

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
          hash[field] = field == 'player_name' ? stat.player&.summoner_name : stat.public_send(field)
        end
      end

      def build_row_array(stat)
        EXPORT_FIELDS.map do |field|
          field == 'player_name' ? stat.player&.summoner_name : stat.public_send(field)
        end
      end
    end
  end
end
