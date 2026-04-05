# frozen_string_literal: true

module Strategy
  module Controllers
    # Tactical Boards Controller
    # Manages tactical board snapshots with player positions and annotations
    class TacticalBoardsController < Api::V1::BaseController
      before_action :set_tactical_board, only: %i[show update destroy statistics]

      # GET /api/v1/strategy/tactical_boards
      def index
        boards = organization_scoped(TacticalBoard).includes(:organization, :created_by, :updated_by, :match, :scrim)
        boards = apply_filters(boards)
        boards = apply_sorting(boards)

        result = paginate(boards)

        render_success({
                         tactical_boards: TacticalBoardSerializer.render_as_hash(result[:data]),
                         total: result[:pagination][:total_count],
                         page: result[:pagination][:current_page],
                         per_page: result[:pagination][:per_page],
                         total_pages: result[:pagination][:total_pages]
                       })
      end

      # GET /api/v1/strategy/tactical_boards/:id
      def show
        render_success({
                         tactical_board: TacticalBoardSerializer.render_as_hash(@tactical_board)
                       })
      end

      # POST /api/v1/strategy/tactical_boards
      def create
        board_params = tactical_board_params
        board = organization_scoped(TacticalBoard).new
        board.assign_attributes(board_params.to_h)
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
                           tactical_board: TacticalBoardSerializer.render_as_hash(board)
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
                           tactical_board: TacticalBoardSerializer.render_as_hash(@tactical_board)
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

      def tactical_board_params # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        # Support both nested format (tactical_board: {map_state:...}) and flat format (name:..., board_state:...)
        # Always prefer the nested tactical_board hash when present — even partial updates
        # (e.g. map_state only, no title) must read from tb, not from top-level params.
        # The previous check `tb[:title].present? || tb[:name].present?` fell back to
        # top-level params whenever an update omitted the title field, causing update({})
        # to be called silently and saving nothing despite returning 200 OK.
        tb = params[:tactical_board]
        source = tb.present? ? tb : params

        permitted = {
          title: source[:title] || source[:name],
          match_id: source[:match_id],
          scrim_id: source[:scrim_id],
          game_time: source[:game_time]
        }.compact

        # Accept map_state or board_state
        map = source[:map_state] || source[:board_state]
        permitted[:map_state] = map.as_json if map.present?

        # Accept annotations
        permitted[:annotations] = source[:annotations].as_json if source[:annotations].present?

        # Merge champion_selections into map_state.players.
        # board_state (already in permitted[:map_state]) carries the authoritative positions
        # from the rendered canvas (drag results). champion_selections carries identity
        # (champion name, role). For each slot, use:
        #   1. x/y from champion_selection if explicitly provided
        #   2. x/y from board_state.players[i] as fallback (preserves drag position)
        #   3. 50 as last resort default
        selections = source[:champion_selections]
        if selections.present? && selections.is_a?(Array)
          existing_players = permitted.dig(:map_state, 'players') || []

          permitted[:map_state] ||= { 'players' => [] }
          permitted[:map_state]['players'] = selections.map.with_index do |cs, idx|
            existing = existing_players[idx] || {}

            # board_state (existing[]) represents the live canvas after a drag — it
            # always wins for position. champion_selections x/y is only a fallback
            # for the initial placement when board_state has no entry yet.
            cs_x = cs[:x].nil? ? cs['x'] : cs[:x]
            cs_y = cs[:y].nil? ? cs['y'] : cs[:y]

            {
              'champion' => cs[:champion] || cs['champion'] || existing['champion'],
              'role' => cs[:role] || cs['role'] || existing['role'],
              'x' => (existing['x'] || cs_x || 50).to_f,
              'y' => (existing['y'] || cs_y || 50).to_f
            }
          end
        end

        permitted
      end
    end
  end
end
