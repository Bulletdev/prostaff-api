# frozen_string_literal: true

module AiIntelligence
  module Controllers
    # Champion pick recommendations powered by the ProStaff ML AI Service.
    #
    # Calls the FastAPI ML service (ai-service container) and falls back to the
    # Ruby DraftSuggester when the ML service is unavailable.
    #
    # The X-AI-Source response header indicates which engine answered:
    #   X-AI-Source: ml_v2   — ML service (XGBoost + Champion2Vec, 327 features)
    #   X-AI-Source: legacy  — DraftSuggester (cosine similarity, AiChampionVector table)
    class RecommendController < Api::V1::BaseController
      before_action :require_predictive_analytics_access!

      # POST /api/v1/ai/recommend-pick
      #
      # @param our_picks      [Array<String>] champions already picked by our team (0-4)
      # @param opponent_picks [Array<String>] champions picked by the opponent (0-5)
      # @param our_bans       [Array<String>] champions banned by our team (optional)
      # @param opponent_bans  [Array<String>] champions banned by opponent (optional)
      # @param patch          [String]        patch version, e.g. "16.08" (optional)
      # @param league         [String]        league identifier, e.g. "LCK" (optional)
      #
      # @return [JSON] { recommendations: [...], source: "ml_v2"|"legacy", model_version: "v2"|nil }
      def recommend_pick
        result = AiRecommendationService.call(
          our_picks: Array(params[:our_picks]),
          opponent_picks: Array(params[:opponent_picks]),
          our_bans: Array(params[:our_bans]),
          opponent_bans: Array(params[:opponent_bans]),
          patch: params[:patch],
          league: params[:league]
        )

        patch = params[:patch]
        if patch.present? && result[:recommendations].is_a?(Array)
          result[:recommendations].each do |rec|
            rec[:patch_win_rate] = ChampionWinrateService.win_rate_for(
              champion: rec[:champion],
              patch: patch
            )
          end
        end

        response.set_header('X-AI-Source', result[:source])
        render_success(result)
      end

      private

      def require_predictive_analytics_access!
        return if current_organization.can_access?('predictive_analytics')

        render_error(
          message: 'AI recommendations require Tier 1 (Professional) subscription',
          code: 'UPGRADE_REQUIRED',
          status: :forbidden
        )
      end
    end
  end
end
