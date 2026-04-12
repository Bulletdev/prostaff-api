# frozen_string_literal: true

module Tournaments
  module Controllers
    # Match listing and check-in for tournament participants.
    #
    # GET  /api/v1/tournaments/:tournament_id/matches          — list all matches
    # GET  /api/v1/tournaments/:tournament_id/matches/:id      — show match detail
    # POST /api/v1/tournaments/:tournament_id/matches/:id/checkin — captain checks in
    class TournamentMatchesController < Api::V1::BaseController
      skip_before_action :authenticate_request!, only: %i[index show]

      before_action :set_tournament
      before_action :set_match, only: %i[show checkin]

      # GET /api/v1/tournaments/:tournament_id/matches
      def index
        matches = @tournament.tournament_matches
                             .includes(:team_a, :team_b, :winner, :loser)
                             .by_round
        render_success(matches.map { |m| TournamentMatchSerializer.new(m).as_json })
      end

      # GET /api/v1/tournaments/:tournament_id/matches/:id
      def show
        my_team = current_tournament_team

        data = TournamentMatchSerializer.new(@match).as_json.merge(
          my_team_checked_in: my_team ? @match.team_checkins.exists?(tournament_team: my_team) : nil,
          opponent_checked_in: opponent_checked_in?(my_team),
          my_team_has_reported: my_team ? @match.match_reports.exists?(tournament_team: my_team) : nil,
          checkin_deadline_at: @match.checkin_deadline_at&.iso8601,
          wo_deadline_at: @match.wo_deadline_at&.iso8601
        )

        render_success(data)
      end

      # POST /api/v1/tournaments/:tournament_id/matches/:id/checkin
      def checkin
        unless @match.open_for_checkin?
          return render_error(
            message: "Check-in is not open for this match (status: #{@match.status})",
            code: 'CHECKIN_NOT_OPEN',
            status: :unprocessable_entity
          )
        end

        my_team = current_tournament_team
        unless my_team
          return render_error(
            message: 'Your organization is not a participant in this match',
            code: 'NOT_PARTICIPANT',
            status: :unprocessable_entity
          )
        end

        if @match.team_checkins.exists?(tournament_team: my_team)
          return render_error(
            message: 'Your team has already checked in',
            code: 'ALREADY_CHECKED_IN',
            status: :unprocessable_entity
          )
        end

        checkin = TeamCheckin.create!(
          tournament_match: @match,
          tournament_team: my_team,
          checked_in_by: current_user,
          checked_in_at: Time.current
        )

        # Transition to in_progress when both teams have checked in
        if @match.both_checked_in?
          @match.update!(status: 'in_progress', started_at: Time.current)
          broadcast_match_update(@match)
        end

        render_success({
                         checked_in: true,
                         checked_in_at: checkin.checked_in_at.iso8601,
                         my_team_checked_in: true,
                         opponent_checked_in: opponent_checked_in?(my_team),
                         match_status: @match.reload.status
                       })
      end

      private

      def set_tournament
        @tournament = Tournament.find_by(id: params[:tournament_id])
        render_error(message: 'Tournament not found', code: 'NOT_FOUND', status: :not_found) unless @tournament
      end

      def set_match
        @match = @tournament.tournament_matches
                            .includes(:team_a, :team_b, :team_checkins, :match_reports)
                            .find_by(id: params[:id])
        render_error(message: 'Match not found', code: 'NOT_FOUND', status: :not_found) unless @match
      end

      # Find the approved tournament team for the current org in this match
      def current_tournament_team
        return nil unless respond_to?(:current_organization, true) && current_organization

        @current_tournament_team ||= TournamentTeam.find_by(
          tournament: @tournament,
          organization: current_organization,
          status: 'approved'
        )
      end

      def opponent_checked_in?(my_team)
        return false unless my_team

        opponent = if @match.team_a_id == my_team.id
                     @match.team_b
                   else
                     @match.team_a
                   end
        return false unless opponent

        @match.team_checkins.any? { |c| c.tournament_team_id == opponent.id }
      end

      def broadcast_match_update(match)
        ActionCable.server.broadcast(
          "tournament_#{match.tournament_id}",
          {
            match_id: match.id,
            status: match.status,
            team_a_score: match.team_a_score,
            team_b_score: match.team_b_score,
            updated_at: match.updated_at.iso8601
          }
        )
      end
    end
  end
end
