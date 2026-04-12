# frozen_string_literal: true

module Tournaments
  module Controllers
    # Match result reporting with dual-validation flow.
    #
    # GET  /api/v1/tournaments/:tournament_id/matches/:match_id/report          — report status
    # POST /api/v1/tournaments/:tournament_id/matches/:match_id/report          — submit report
    # POST /api/v1/tournaments/:tournament_id/matches/:match_id/report/admin_resolve — admin resolves dispute
    class MatchReportsController < Api::V1::BaseController
      before_action :set_tournament
      before_action :set_match
      before_action :set_my_team, only: %i[show create]
      before_action :require_admin!, only: %i[admin_resolve]

      # GET /api/v1/tournaments/:tournament_id/matches/:match_id/report
      def show
        my_report       = @match.match_reports.find_by(tournament_team: @my_team)
        opponent_team   = opponent_of(@my_team)
        opponent_report = opponent_team ? @match.match_reports.find_by(tournament_team: opponent_team) : nil

        render_success({
                         match_status: @match.status,
                         my_report: MatchReportSerializer.new(my_report).as_json,
                         opponent_reported: opponent_report&.submitted? || false,
                         # Only expose opponent scores after both have reported (no oracle attack)
                         opponent_report: both_reported? ? MatchReportSerializer.new(opponent_report).as_json : nil,
                         deadline_at: my_report&.deadline_at&.iso8601 || 2.hours.from_now.iso8601
                       })
      end

      # POST /api/v1/tournaments/:tournament_id/matches/:match_id/report
      def create
        result = MatchConfirmationService.new(
          match: @match,
          team: @my_team,
          user: current_user,
          team_a_score: params[:team_a_score],
          team_b_score: params[:team_b_score],
          evidence_url: params[:evidence_url]
        ).call

        if result[:status] == :error
          render_error(message: result[:message], code: 'VALIDATION_ERROR', status: :unprocessable_entity)
        else
          render_success({
                           status: result[:status],
                           report: MatchReportSerializer.new(result[:report]).as_json,
                           message: status_message(result[:status])
                         })
        end
      end

      # POST /api/v1/tournaments/:tournament_id/matches/:match_id/report/admin_resolve
      def admin_resolve
        unless @match.disputed?
          return render_error(
            message: "Match is not in a disputed state (status: #{@match.status})",
            code: 'NOT_DISPUTED',
            status: :unprocessable_entity
          )
        end

        winner_id = params[:winner_team_id]
        winner = @match.team_a_id == winner_id ? @match.team_a : @match.team_b
        loser  = winner == @match.team_a ? @match.team_b : @match.team_a

        unless winner
          return render_error(message: 'Invalid winner_team_id', code: 'INVALID_PARAMS', status: :unprocessable_entity)
        end

        ActiveRecord::Base.transaction do
          @match.match_reports.update_all(status: 'confirmed', confirmed_at: Time.current)
          @match.update!(
            team_a_score: params[:team_a_score] || @match.team_a_score,
            team_b_score: params[:team_b_score] || @match.team_b_score,
            status: 'confirmed'
          )
          BracketProgressionService.new(@match, winner: winner, loser: loser).call
        end

        render_success({ resolved: true, winner_team_id: winner.id })
      end

      private

      def set_tournament
        @tournament = Tournament.find_by(id: params[:tournament_id])
        render_error(message: 'Tournament not found', code: 'NOT_FOUND', status: :not_found) unless @tournament
      end

      def set_match
        @match = @tournament.tournament_matches
                            .includes(:team_a, :team_b, :match_reports)
                            .find_by(id: params[:match_id])
        render_error(message: 'Match not found', code: 'NOT_FOUND', status: :not_found) unless @match
      end

      def set_my_team
        return unless current_organization

        @my_team = TournamentTeam.find_by(
          tournament: @tournament,
          organization: current_organization,
          status: 'approved'
        )
        return if @my_team

        render_error(message: 'Your team is not enrolled in this tournament', code: 'NOT_ENROLLED',
                     status: :forbidden)
      end

      def require_admin!
        return if current_user&.admin_or_owner?

        render_error(message: 'Admin access required', code: 'FORBIDDEN', status: :forbidden)
      end

      def opponent_of(team)
        return nil unless team

        if @match.team_a_id == team.id
          @match.team_b
        else
          @match.team_a
        end
      end

      def both_reported?
        @match.match_reports.where(status: 'submitted').count == 2
      end

      def status_message(status)
        {
          submitted: 'Result submitted. Waiting for opponent to confirm.',
          confirmed: 'Both reports match. Result confirmed, bracket advanced.',
          disputed: 'Scores diverge. An admin will resolve the dispute.'
        }[status] || 'Report received.'
      end
    end
  end
end
