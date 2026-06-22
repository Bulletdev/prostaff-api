# frozen_string_literal: true

module Scouting
  module Controllers
    # GET /api/v1/scouting/gcd-free-agents
    #
    # Lists MarketRegistration records where the player has no current team
    # (team_name blank) or whose contract has already expired.
    # Enriched with solo_queue_id, image_url, and org-scoped already_watching flag.
    class GcdFreeAgentsController < Api::V1::BaseController
      RECORDS_PER_PAGE = 25

      # @param region [String] Stored region name (e.g. 'Korea') — translated by frontend
      # @param role [String] Player role (Top, Jng, Mid, Bot, Sup, Coach)
      # @param with_soloqueue [String] 'true' to filter only players with solo queue ID
      # @param page [Integer] Page number (default: 1)
      def index
        authorize MarketRegistration, :index?

        watching_names = build_watching_names
        scope = build_scope
        total = scope.count
        result = paginate(scope, per_page: RECORDS_PER_PAGE)
        per_page_used = result[:pagination][:per_page]

        render_success({
                         free_agents: result[:data].map { |r| serialize_agent(r, watching_names) },
                         pagination: result[:pagination].merge(
                           total_count: total,
                           total_pages: [(total.to_f / per_page_used).ceil, 1].max
                         )
                       })
      end

      private

      def build_watching_names
        ScoutingTarget
          .joins(:scouting_watchlists)
          .where(scouting_watchlists: { organization_id: current_organization.id })
          .where.not(professional_name: nil)
          .pluck(Arel.sql('LOWER(professional_name)'))
          .to_set
      end

      def build_scope
        scope = MarketRegistration
                .free_agents
                .recent_snapshot
                .includes(:scouting_target)
                .for_region(params[:region])
        scope = scope.where(role: params[:role]) if params[:role].present?
        scope = scope.with_soloqueue if params[:with_soloqueue] == 'true'
        scope.order(:player_external_name)
      end

      def serialize_agent(reg, watching_names)
        MarketRegistrationSerializer.render_as_hash(reg).merge(
          already_watching: watching_names.include?(reg.player_external_name.downcase),
          contract_status: contract_status(reg.contract_end_date)
        )
      end

      def contract_status(date)
        return 'unknown' unless date
        return 'expired' if date < Date.current
        return 'expiring_soon' if date <= (Date.current + 90.days)

        'active'
      end
    end
  end
end
