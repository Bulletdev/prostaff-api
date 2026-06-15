# frozen_string_literal: true

module AiIntelligence
  module Controllers
    # Adversary draft profiling endpoint.
    #
    # Returns a team's historical draft tendencies (bans + priority picks by role)
    # by merging Elasticsearch professional match data with local competitive_matches.
    #
    # Requires Tier 1 (Professional) subscription — feature: predictive_analytics.
    # Uses 2-minute cache via ProStaffScraperService#fetch_adversary_profile.
    class AdversaryDraftController < Api::V1::BaseController
      before_action :require_predictive_analytics_access!
      before_action :require_team_param!

      # GET /api/v1/ai/draft/adversary-profile
      #
      # @param team   [String]       required — team name as indexed in ES (e.g. 'LOUD')
      # @param league [String]       optional — filter by league (e.g. 'CBLOL')
      # @param last_n [Integer]      optional — last N games to analyse (default 20)
      def adversary_profile
        profiler = AdversaryDraftProfiler.new(
          team: params[:team],
          organization: current_organization,
          league: params[:league].presence,
          last_n: [params[:last_n]&.to_i || 20, 100].min
        )

        render_success({ adversary_profile: profiler.call })
      end

      private

      def require_predictive_analytics_access!
        return if current_organization.can_access?('predictive_analytics')

        render_error(
          message: 'Adversary draft profiling requires a Professional subscription',
          code: 'UPGRADE_REQUIRED',
          status: :forbidden
        )
      end

      def require_team_param!
        return if params[:team].present?

        render_error(
          message: 'team param is required',
          code: 'MISSING_PARAM',
          status: :bad_request
        )
      end
    end
  end
end
