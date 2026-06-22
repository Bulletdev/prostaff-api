# frozen_string_literal: true

module Scouting
  module Controllers
    # Market Registrations Controller
    # Exposes global GCD (Global Contract Database) data sourced from Leaguepedia.
    # Records are synced nightly by Scouting::SyncGcdJob — they are read-only for most users.
    class MarketRegistrationsController < Api::V1::BaseController
      # Pre-built ORDER BY clauses — all values are string literals so no SQL injection is possible.
      # Keys: "{sort_by}_{sort_dir}" where sort_by and sort_dir come from the request params.
      ORDER_CLAUSES = {
        'player_asc' => 'player_external_name ASC NULLS LAST',
        'player_desc' => 'player_external_name DESC NULLS LAST',
        'team_asc' => 'team_name ASC NULLS LAST',
        'team_desc' => 'team_name DESC NULLS LAST',
        'region_asc' => 'region ASC NULLS LAST',
        'region_desc' => 'region DESC NULLS LAST',
        'role_asc' => 'role ASC NULLS LAST',
        'role_desc' => 'role DESC NULLS LAST',
        'residency_asc' => 'residency ASC NULLS LAST',
        'residency_desc' => 'residency DESC NULLS LAST',
        'contract_end_asc' => 'contract_end_date ASC NULLS LAST',
        'contract_end_desc' => 'contract_end_date DESC NULLS LAST',
        'status_asc' => 'contract_end_date ASC NULLS LAST',
        'status_desc' => 'contract_end_date DESC NULLS LAST'
      }.freeze

      DEFAULT_ORDER = 'player_external_name ASC NULLS LAST'
      RECORDS_PER_PAGE = 50

      # GET /api/v1/scouting/market-registrations
      # Returns paginated GCD records with optional filters and server-side sort.
      #
      # @param [String]  region          Stored region name (e.g. 'Korea') — translated by frontend
      # @param [String]  expiring_before ISO date — only records with contract_end_date <= this value
      # @param [String]  q               Text search on player_external_name and team_name (ILIKE)
      # @param [Boolean] expired_only    When 'true', only records with contract_end_date < today
      # @param [String]  sort_by         player|team|region|role|residency|contract_end|status
      # @param [String]  sort_dir        asc|desc (default: asc)
      # @param [Integer] page            Page number (default: 1)
      def index
        authorize MarketRegistration, :index?

        scope = filtered_registrations
        total = scope.count
        result = paginate(scope.order(sort_order), per_page: RECORDS_PER_PAGE)

        render_success({
                         market_registrations: MarketRegistrationSerializer.render_as_hash(result[:data]),
                         pagination: result[:pagination].merge(
                           total_count: total,
                           total_pages: [(total.to_f / RECORDS_PER_PAGE).ceil, 1].max
                         ),
                         source_notice: 'Data from Leaguepedia (lol.fandom.com), CC BY-SA 3.0.'
                       })
      end

      # GET /api/v1/scouting/market-registrations/:id
      def show
        # nosemgrep: ruby.rails.security.brakeman.check-unscoped-find.check-unscoped-find
        registration = MarketRegistration.find(params[:id])
        authorize registration

        render_success({
                         market_registration: MarketRegistrationSerializer.render_as_hash(registration)
                       })
      end

      private

      def filtered_registrations
        scope = MarketRegistration
                  .for_region(params[:region])
                  .expiring_before(params[:expiring_before])
                  .search_query(params[:q])
        scope = scope.free_agents      if params[:free_agents_only] == 'true'
        scope = scope.expired_contracts if params[:expired_only] == 'true'
        scope
      end

      def sort_order
        key = "#{params[:sort_by]}_#{params[:sort_dir]&.downcase}"
        Arel.sql(ORDER_CLAUSES.fetch(key, DEFAULT_ORDER))
      end
    end
  end
end
