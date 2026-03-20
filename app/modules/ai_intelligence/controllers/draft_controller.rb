# frozen_string_literal: true

module AiIntelligence
  module Controllers
    # REST endpoint for AI draft analysis.
    # Requires Tier 1 (Professional) subscription — feature: predictive_analytics.
    class DraftController < Api::V1::BaseController
      before_action :require_predictive_analytics_access!

      # POST /api/v1/ai/draft/analyze
      def analyze
        result = DraftAnalyzer.call(
          team_a: params.require(:team_a),
          team_b: params.require(:team_b),
          patch: params[:patch]
        )
        render_success(DraftAnalysisBlueprint.render_as_hash(result))
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
