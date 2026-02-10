# frozen_string_literal: true

module Api
  module V1
    module Scouting
      # Watchlist Controller
      # Manages organization-specific player scouting watchlists
      class WatchlistController < Api::V1::BaseController
        before_action :set_authorized_target, only: [:create, :destroy]
        # GET /api/v1/scouting/watchlist
        # Returns high-priority scouting targets in org's watchlist
        def index
          watchlists = organization_scoped(ScoutingWatchlist)
                       .where(priority: %w[high critical])
                       .where(status: %w[watching contacted negotiating])
                       .includes(:scouting_target, :added_by, :assigned_to)
                       .order(priority: :desc, created_at: :desc)

          watchlist_data = watchlists.map do |watchlist|
            JSON.parse(ScoutingTargetSerializer.render(watchlist.scouting_target, watchlist: watchlist))
          end

          render_success({
                           watchlist: watchlist_data,
                           count: watchlists.size
                         })
        end

        # POST /api/v1/scouting/watchlist
        # Add a scouting target to watchlist (sets priority to high)
        def create
          # @target is set by before_action :set_authorized_target

          # Find or create watchlist entry
          watchlist = organization_scoped(ScoutingWatchlist)
                      .find_or_initialize_by(scouting_target: @target)

          watchlist.assign_attributes(
            added_by: current_user,
            priority: 'high',
            status: watchlist.new_record? ? 'watching' : watchlist.status
          )

          if watchlist.save
            log_user_action(
              action: 'add_to_watchlist',
              entity_type: 'ScoutingWatchlist',
              entity_id: watchlist.id,
              new_values: { priority: 'high' }
            )

            render_created({
                             scouting_target: JSON.parse(
                               ScoutingTargetSerializer.render(@target, watchlist: watchlist)
                             )
                           }, message: 'Added to watchlist')
          else
            render_error(
              message: 'Failed to add to watchlist',
              code: 'UPDATE_ERROR',
              status: :unprocessable_entity
            )
          end
        end

        # DELETE /api/v1/scouting/watchlist/:id
        # Remove from watchlist (doesn't delete target, just lowers priority)
        def destroy
          # @target is set by before_action :set_authorized_target
          watchlist = organization_scoped(ScoutingWatchlist).find_by(scouting_target: @target)

          if watchlist
            # Lower priority instead of deleting
            if watchlist.update(priority: 'medium')
              log_user_action(
                action: 'remove_from_watchlist',
                entity_type: 'ScoutingWatchlist',
                entity_id: watchlist.id,
                new_values: { priority: 'medium' }
              )

              render_deleted(message: 'Removed from watchlist')
            else
              render_error(
                message: 'Failed to remove from watchlist',
                code: 'UPDATE_ERROR',
                status: :unprocessable_entity
              )
            end
          else
            render_error(
              message: 'Not in watchlist',
              code: 'NOT_FOUND',
              status: :not_found
            )
          end
        end

        private

        # Finds and authorizes a scouting target for actions that need it
        # ScoutingTarget is global, but access is controlled by user role
        def set_authorized_target
          target_id = params[:scouting_target_id] || params[:id]

          # Using policy_scope ensures only authorized users (coach+) can access
          authorized_targets = policy_scope(ScoutingTarget)
          @target = authorized_targets.find_by(id: target_id)

          # Raise not found if target doesn't exist or user isn't authorized
          raise ActiveRecord::RecordNotFound, "ScoutingTarget not found" unless @target
        end
      end
    end
  end
end
