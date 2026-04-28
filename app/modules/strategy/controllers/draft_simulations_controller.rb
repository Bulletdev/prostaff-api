# frozen_string_literal: true

module Strategy
  module Controllers
    # Draft Simulations Controller
    # Manages live draft simulator state per series (multi-game BO3/BO5)
    class DraftSimulationsController < Api::V1::BaseController
      before_action :set_draft_simulation, only: %i[update destroy]

      # GET /api/v1/strategy/draft-simulations/:series_id
      def index
        simulations = organization_scoped(DraftSimulation).for_series(params[:series_id])

        render_success({
                         draft_simulations: simulations.as_json
                       })
      end

      # POST /api/v1/strategy/draft-simulations
      def create
        simulation = organization_scoped(DraftSimulation).new(create_params)
        simulation.organization = current_organization

        if simulation.save
          render_created({
                           draft_simulation: simulation.as_json
                         }, message: 'Draft simulation created successfully')
        else
          render_error(
            message: 'Failed to create draft simulation',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: simulation.errors.as_json
          )
        end
      end

      # PATCH /api/v1/strategy/draft-simulations/:id
      def update
        if @draft_simulation.update(update_params)
          render_updated({
                           draft_simulation: @draft_simulation.as_json
                         })
        else
          render_error(
            message: 'Failed to update draft simulation',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: @draft_simulation.errors.as_json
          )
        end
      end

      # DELETE /api/v1/strategy/draft-simulations/:id
      def destroy
        if @draft_simulation.destroy
          render_deleted(message: 'Draft simulation deleted successfully')
        else
          render_error(
            message: 'Failed to delete draft simulation',
            code: 'DELETE_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      private

      def set_draft_simulation
        @draft_simulation = organization_scoped(DraftSimulation).find(params[:id])
      end

      def create_params
        params.require(:draft_simulation).permit(
          :series_id,
          :patch,
          :league,
          :our_side,
          :team1_name,
          :team2_name,
          :fearless,
          fearless_used: {}
        )
      end

      def update_params
        params.require(:draft_simulation).permit(
          :game_number,
          :done,
          :fearless_used,
          blue_bans: [],
          red_bans: [],
          blue_picks: [],
          red_picks: [],
          fearless_used: {}
        )
      end
    end
  end
end
