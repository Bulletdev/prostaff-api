# frozen_string_literal: true

module Analytics
  module Controllers
    # Ping Profile Analytics Controller
    #
    # Returns a player's communication profile derived from ping usage across matches.
    # Requires ping data to be present (populated from Riot Match v5 API, patch 12.10+).
    #
    # @example
    #   GET /api/v1/analytics/players/:player_id/ping-profile
    #   GET /api/v1/analytics/players/:player_id/ping-profile?games=30
    class PingProfileController < Api::V1::BaseController
      before_action :set_player, only: %i[show]

      def show
        games = [params.fetch(:games, 20).to_i, 50].min

        profile = PingProfileService.new(@player, matches_limit: games).calculate

        render_success({
                         player: PlayerSerializer.render_as_hash(@player),
                         ping_profile: profile
                       })
      end

      private

      def set_player
        @player = organization_scoped(Player).find(params[:player_id])
      end
    end
  end
end
