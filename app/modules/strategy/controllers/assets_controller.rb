# frozen_string_literal: true

module Strategy
  module Controllers
    # Assets Controller
    # Provides champion and map asset URLs from Data Dragon
    class AssetsController < Api::V1::BaseController
      skip_before_action :authenticate_request!, only: %i[champion_assets map_assets]

      # GET /api/v1/strategy/assets/champion/:champion_name
      def champion_assets
        champion_name = params[:champion_name]

        assets = DraftAnalysisService.champion_assets(champion_name)

        render_success({
                         champion: champion_name,
                         assets: assets
                       })
      rescue StandardError => e
        render_error(
          message: "Failed to fetch champion assets: #{e.message}",
          code: 'ASSET_FETCH_ERROR',
          status: :internal_server_error
        )
      end

      # GET /api/v1/strategy/assets/map
      def map_assets
        assets = DraftAnalysisService.map_assets

        render_success({
                         assets: assets
                       })
      rescue StandardError => e
        render_error(
          message: "Failed to fetch map assets: #{e.message}",
          code: 'ASSET_FETCH_ERROR',
          status: :internal_server_error
        )
      end
    end
  end
end
