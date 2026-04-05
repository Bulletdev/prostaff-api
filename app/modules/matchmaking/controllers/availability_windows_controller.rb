# frozen_string_literal: true

module Matchmaking
  module Controllers
    # Controller for managing organization availability windows for matchmaking.
    class AvailabilityWindowsController < Api::V1::BaseController
      before_action :set_window, only: %i[show update destroy]

      # GET /api/v1/matchmaking/availability-windows
      def index
        windows = organization_scoped(AvailabilityWindow).order(:day_of_week, :start_hour)
        windows = windows.by_game(params[:game]) if params[:game].present?
        windows = windows.active if params[:active] == 'true'
        render_success({ availability_windows: AvailabilityWindowSerializer.render_as_hash(windows) })
      end

      # GET /api/v1/matchmaking/availability-windows/:id
      def show
        render_success({ availability_window: AvailabilityWindowSerializer.render_as_hash(@window) })
      end

      # POST /api/v1/matchmaking/availability-windows
      def create
        window = organization_scoped(AvailabilityWindow).new(window_params)
        window.organization = current_organization
        if window.save
          render_created({ availability_window: AvailabilityWindowSerializer.render_as_hash(window) },
                         message: 'Availability window created')
        else
          render_error(message: 'Failed to create availability window', code: 'VALIDATION_ERROR',
                       status: :unprocessable_entity, details: window.errors.as_json)
        end
      end

      # PATCH /api/v1/matchmaking/availability-windows/:id
      def update
        if @window.update(window_params)
          render_updated({ availability_window: AvailabilityWindowSerializer.render_as_hash(@window) })
        else
          render_error(message: 'Failed to update availability window', code: 'VALIDATION_ERROR',
                       status: :unprocessable_entity, details: @window.errors.as_json)
        end
      end

      # DELETE /api/v1/matchmaking/availability-windows/:id
      def destroy
        @window.destroy!
        render_deleted(message: 'Availability window deleted')
      end

      private

      def set_window
        @window = organization_scoped(AvailabilityWindow).find(params[:id])
      end

      def window_params
        params.require(:availability_window).permit(
          :day_of_week, :start_hour, :end_hour, :timezone,
          :game, :region, :tier_preference, :focus_area, :draft_type, :active, :expires_at
        )
      end
    end
  end
end
