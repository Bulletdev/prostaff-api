# frozen_string_literal: true

module Tournaments
  module Controllers
    # CRUD for tournaments.
    #
    # GET    /api/v1/tournaments            — list (public)
    # GET    /api/v1/tournaments/:id        — show with bracket (public)
    # POST   /api/v1/tournaments            — create (admin only)
    # PATCH  /api/v1/tournaments/:id        — update (admin only)
    # POST   /api/v1/tournaments/:id/generate_bracket — trigger bracket gen (admin only)
    class TournamentsController < Api::V1::BaseController
      skip_before_action :authenticate_request!, only: %i[index show]

      before_action :set_tournament, only: %i[show update generate_bracket]
      before_action :require_admin!, only: %i[create update generate_bracket]

      # GET /api/v1/tournaments
      def index
        tournaments = Tournament.active.by_scheduled
        render_success(tournaments.map { |t| TournamentSerializer.new(t).as_json })
      end

      # GET /api/v1/tournaments/:id
      def show
        render_success(TournamentSerializer.new(@tournament, with_bracket: true).as_json)
      end

      # POST /api/v1/tournaments
      def create
        tournament = Tournament.new(tournament_params)

        if tournament.save
          render_created(TournamentSerializer.new(tournament).as_json)
        else
          render_error(
            message: tournament.errors.full_messages.join(', '),
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      # PATCH /api/v1/tournaments/:id
      def update
        if @tournament.update(tournament_params)
          render_success(TournamentSerializer.new(@tournament).as_json)
        else
          render_error(
            message: @tournament.errors.full_messages.join(', '),
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      # POST /api/v1/tournaments/:id/generate_bracket
      def generate_bracket
        if @tournament.bracket_generated?
          return render_error(
            message: 'Bracket already generated',
            code: 'BRACKET_EXISTS',
            status: :unprocessable_entity
          )
        end

        BracketGeneratorService.new(@tournament).call
        @tournament.update!(status: 'in_progress')
        render_success(TournamentSerializer.new(@tournament, with_bracket: true).as_json)
      end

      private

      def set_tournament
        @tournament = Tournament.find_by(id: params[:id])
        render_error(message: 'Tournament not found', code: 'NOT_FOUND', status: :not_found) unless @tournament
      end

      def require_admin!
        return if current_user&.admin_or_owner?

        render_error(message: 'Admin access required', code: 'FORBIDDEN', status: :forbidden)
      end

      def tournament_params
        params.permit(
          :name, :game, :format, :status, :max_teams,
          :entry_fee_cents, :prize_pool_cents, :bo_format,
          :current_round_label, :rules,
          :registration_closes_at, :scheduled_start_at
        )
      end
    end
  end
end
