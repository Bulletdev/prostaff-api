# frozen_string_literal: true

module Scouting
  module Controllers
    # Market Registrations Controller
    # Exposes global GCD (Global Contract Database) data sourced from Leaguepedia.
    # Records are synced nightly by Scouting::SyncGcdJob — they are read-only for most users.
    class MarketRegistrationsController < Api::V1::BaseController
      # GET /api/v1/scouting/market-registrations
      # Returns paginated market registration records with optional filters.
      #
      # @param [String] region   Filter by region (e.g. 'CBLOL', 'LCK')
      # @param [String] expiring_before  ISO date — only records with contract_end_date <= this value
      # @param [Integer] page    Page number (default 1)
      def index
        authorize MarketRegistration, :index?

        registrations = filtered_registrations
        result = paginate(registrations, per_page: 50)

        render_success({
          market_registrations: MarketRegistrationSerializer.render_as_hash(result[:data]),
          pagination: result[:pagination],
          source_notice: 'Data from Leaguepedia (lol.fandom.com), CC BY-SA 3.0.'
        })
      end

      # GET /api/v1/scouting/market-registrations/:id
      def show
        registration = MarketRegistration.find(params[:id])
        authorize registration

        render_success({
          market_registration: MarketRegistrationSerializer.render_as_hash(registration)
        })
      end

      private

      def filtered_registrations
        MarketRegistration
          .for_region(params[:region])
          .expiring_before(params[:expiring_before])
          .by_player
      end
    end
  end
end
