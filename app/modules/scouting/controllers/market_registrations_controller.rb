# frozen_string_literal: true

module Scouting
  module Controllers
    # Market Registrations Controller
    # Exposes global GCD (Global Contract Database) data sourced from Leaguepedia.
    # Records are synced nightly by Scouting::SyncGcdJob — they are read-only for most users.
    class MarketRegistrationsController < Api::V1::BaseController
      # Allowlist mapping frontend sort_by keys to actual DB column names.
      # status and contract_end both sort by contract_end_date (status is derived from it).
      SORT_COLUMNS = {
        'player'       => 'player_external_name',
        'team'         => 'team_name',
        'region'       => 'region',
        'role'         => 'role',
        'residency'    => 'residency',
        'contract_end' => 'contract_end_date',
        'status'       => 'contract_end_date'
      }.freeze
      SORT_DIRS = %w[asc desc].freeze

      # GET /api/v1/scouting/market-registrations
      # Returns paginated market registration records with optional filters and server-side sort.
      #
      # @param [String]  region          Filter by region (stored name e.g. 'Korea', or code e.g. 'LCK')
      # @param [String]  expiring_before ISO date — only records with contract_end_date <= this value
      # @param [String]  sort_by         Column key: player|team|region|role|residency|contract_end|status
      # @param [String]  sort_dir        Direction: asc|desc (default: asc)
      # @param [Integer] page            Page number (default 1)
      def index
        authorize MarketRegistration, :index?

        registrations = filtered_registrations.order(sort_order)
        result = paginate(registrations, per_page: 50)

        render_success({
                         market_registrations: MarketRegistrationSerializer.render_as_hash(result[:data]),
                         pagination: result[:pagination],
                         source_notice: 'Data from Leaguepedia (lol.fandom.com), CC BY-SA 3.0.'
                       })
      end

      # GET /api/v1/scouting/market-registrations/:id
      def show
        # MarketRegistration is global public GCD data (no org scope by design).
        # Access is controlled by Pundit (MarketRegistrationPolicy).
        registration = MarketRegistration.find(params[:id]) # nosemgrep: ruby.rails.security.brakeman.check-unscoped-find.check-unscoped-find
        authorize registration

        render_success({
                         market_registration: MarketRegistrationSerializer.render_as_hash(registration)
                       })
      end

      private

      def filtered_registrations
        base = MarketRegistration
                 .for_region(params[:region])
                 .expiring_before(params[:expiring_before])
        params[:expired_only] == 'true' ? base.expired_contracts : base
      end

      def sort_order
        col = SORT_COLUMNS.fetch(params[:sort_by].to_s, 'player_external_name')
        dir = SORT_DIRS.include?(params[:sort_dir].to_s.downcase) ? params[:sort_dir].downcase : 'asc'
        Arel.sql("#{col} #{dir} NULLS LAST")
      end
    end
  end
end
