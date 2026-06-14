# frozen_string_literal: true

module Strategy
  module Controllers
    # Draft Simulations Controller
    # Manages live draft simulator state per series (multi-game BO3/BO5)
    class DraftSimulationsController < Api::V1::BaseController
      before_action :set_draft_simulation, only: %i[update destroy]

      # GET /api/v1/strategy/draft-simulations
      def list
        series = organization_scoped(DraftSimulation)
                 .select(:series_id, :team1_name, :team2_name, :patch, :league, :our_side, :fearless, :created_at,
                         :blue_picks, :red_picks, :blue_bans, :red_bans)
                 .order(created_at: :desc)
                 .group_by(&:series_id)
                 .map { |series_id, games| build_series_summary(series_id, games) }

        render_success({ series: series })
      end

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

      # DELETE /api/v1/strategy/draft-simulations/series/:series_id
      def destroy_series
        simulations = organization_scoped(DraftSimulation).where(series_id: params[:series_id])
        return render_error(message: 'Series not found', code: 'NOT_FOUND', status: :not_found) if simulations.empty?

        simulations.destroy_all
        render_deleted(message: 'Series deleted successfully')
      end

      private

      def set_draft_simulation
        @draft_simulation = organization_scoped(DraftSimulation).find(params[:id])
      end

      def build_series_summary(series_id, games)
        first = games.first
        total_picks = games.sum { |g| Array(g.blue_picks).size + Array(g.red_picks).size }
        total_bans  = games.sum { |g| Array(g.blue_bans).size + Array(g.red_bans).size }

        {
          series_id: series_id,
          team1_name: first.team1_name,
          team2_name: first.team2_name,
          patch: first.patch,
          league: first.league,
          our_side: first.our_side,
          fearless: first.fearless,
          game_count: games.size,
          total_picks: total_picks,
          total_bans: total_bans,
          created_at: first.created_at
        }
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
