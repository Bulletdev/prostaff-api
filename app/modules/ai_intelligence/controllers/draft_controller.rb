# frozen_string_literal: true

module AiIntelligence
  module Controllers
    # REST endpoint for AI draft analysis.
    # Requires Tier 1 (Professional) subscription — feature: predictive_analytics.
    class DraftController < Api::V1::BaseController
      before_action :require_predictive_analytics_access!

      # POST /api/v1/ai/draft/analyze
      def analyze
        team_a = params.require(:team_a)
        team_b = params.require(:team_b)
        patch  = params[:patch]

        result = DraftAnalyzer.call(team_a: team_a, team_b: team_b, patch: patch)

        if result.source == 'ml_v2'
          PredictionLogger.log(
            blue_picks:         Array(team_a),
            red_picks:          Array(team_b),
            predicted_win_prob: result.win_probability,
            source:             result.source,
            patch:              patch,
            league:             params[:league]
          )
        end

        blueprint = DraftAnalysisBlueprint.render_as_hash(result)

        all_champs = (Array(team_a) + Array(team_b)).uniq
        champion_win_rates = ChampionWinrateService.bulk_lookup(all_champs, patch)
        blueprint[:champion_win_rates] = champion_win_rates

        render_success(blueprint)
      end

      # POST /api/v1/ai/draft/synergy-matrix
      def synergy_matrix
        champions = Array(params[:champions]).first(10)
        return render json: { error: 'champions required' }, status: :bad_request if champions.size < 2

        result = SynergyMatrixService.call(champions: champions)
        render_success(result)
      end

      private

      def require_predictive_analytics_access!
        return if current_organization.can_access?('predictive_analytics')

        render_error(
          message: 'AI draft analysis requires Tier 1 (Professional) subscription',
          code: 'UPGRADE_REQUIRED',
          status: :forbidden
        )
      end
    end
  end
end
