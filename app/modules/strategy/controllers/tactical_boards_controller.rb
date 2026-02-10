# frozen_string_literal: true

module Api
  module V1
    module Strategy
      # Tactical Boards Controller
      # Manages tactical board snapshots with player positions and annotations
      class TacticalBoardsController < Api::V1::BaseController
        before_action :set_tactical_board, only: %i[show update destroy statistics]

        # GET /api/v1/strategy/tactical_boards
        def index
          boards = organization_scoped(TacticalBoard).includes(:created_by, :updated_by, :match, :scrim)
          boards = apply_filters(boards)
          boards = apply_sorting(boards)

          result = paginate(boards)

          render_success({
                           tactical_boards: Strategy::Serializers::TacticalBoardSerializer.render_as_hash(result[:data]),
                           total: result[:pagination][:total_count],
                           page: result[:pagination][:current_page],
                           per_page: result[:pagination][:per_page],
                           total_pages: result[:pagination][:total_pages]
                         })
        end

        # GET /api/v1/strategy/tactical_boards/:id
        def show
          render_success({
                           tactical_board: Strategy::Serializers::TacticalBoardSerializer.render_as_hash(@tactical_board)
                         })
        end

        # POST /api/v1/strategy/tactical_boards
        def create
          board = organization_scoped(TacticalBoard).new(tactical_board_params)
          board.organization = current_organization
          board.created_by = current_user
          board.updated_by = current_user

          if board.save
            log_user_action(
              action: 'create',
              entity_type: 'TacticalBoard',
              entity_id: board.id,
              new_values: board.attributes
            )

            render_created({
                             tactical_board: Strategy::Serializers::TacticalBoardSerializer.render_as_hash(board)
                           }, message: 'Tactical board created successfully')
          else
            render_error(
              message: 'Failed to create tactical board',
              code: 'VALIDATION_ERROR',
              status: :unprocessable_entity,
              details: board.errors.as_json
            )
          end
        end

        # PATCH /api/v1/strategy/tactical_boards/:id
        def update
          old_values = @tactical_board.attributes.dup
          @tactical_board.updated_by = current_user

          if @tactical_board.update(tactical_board_params)
            log_user_action(
              action: 'update',
              entity_type: 'TacticalBoard',
              entity_id: @tactical_board.id,
              old_values: old_values,
              new_values: @tactical_board.attributes
            )

            render_updated({
                             tactical_board: Strategy::Serializers::TacticalBoardSerializer.render_as_hash(@tactical_board)
                           })
          else
            render_error(
              message: 'Failed to update tactical board',
              code: 'VALIDATION_ERROR',
              status: :unprocessable_entity,
              details: @tactical_board.errors.as_json
            )
          end
        end

        # DELETE /api/v1/strategy/tactical_boards/:id
        def destroy
          if @tactical_board.destroy
            log_user_action(
              action: 'delete',
              entity_type: 'TacticalBoard',
              entity_id: @tactical_board.id,
              old_values: @tactical_board.attributes
            )

            render_deleted(message: 'Tactical board deleted successfully')
          else
            render_error(
              message: 'Failed to delete tactical board',
              code: 'DELETE_ERROR',
              status: :unprocessable_entity
            )
          end
        end

        # GET /api/v1/strategy/tactical_boards/:id/statistics
        def statistics
          stats = @tactical_board.statistics

          render_success({
                           tactical_board_id: @tactical_board.id,
                           statistics: stats
                         })
        end

        private

        def set_tactical_board
          @tactical_board = organization_scoped(TacticalBoard).find(params[:id])
        end

        def apply_filters(boards)
          boards = boards.for_match(params[:match_id]) if params[:match_id].present?
          boards = boards.for_scrim(params[:scrim_id]) if params[:scrim_id].present?
          boards = boards.by_time(params[:game_time]) if params[:game_time].present?
          boards
        end

        def apply_sorting(boards)
          sort_by = params[:sort_by] || 'created_at'
          sort_order = params[:sort_order]&.downcase == 'asc' ? :asc : :desc

          boards.order(sort_by => sort_order)
        end

        def tactical_board_params
          params.require(:tactical_board).permit(
            :title,
            :match_id,
            :scrim_id,
            :game_time,
            map_state: {},
            annotations: []
          )
        end
      end
    end
  end
end
