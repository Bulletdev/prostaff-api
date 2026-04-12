# frozen_string_literal: true

module Tournaments
  # Auto-WO job scheduled when check-in opens.
  # Fires at checkin_deadline_at + 15 minutes.
  # If a team failed to check in, they forfeit — the opposing team wins by W.O.
  # If both failed to check in, match is marked walkover with no winner (admin decides).
  #
  # Scheduling: called from TournamentMatchesController (future: when checkin_open event fires).
  # Schedule: Tournaments::TournamentWalkoverJob.set(wait_until: match.wo_deadline_at).perform_later(match.id)
  class TournamentWalkoverJob < ApplicationJob
    queue_as :default

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def perform(match_id)
      match = TournamentMatch.includes(:team_a, :team_b, :team_checkins).find_by(id: match_id)
      return unless match
      return unless match.status == 'checkin_open'

      team_a_in = match.team_checkins.any? { |c| c.tournament_team_id == match.team_a_id }
      team_b_in = match.team_checkins.any? { |c| c.tournament_team_id == match.team_b_id }

      return if team_a_in && team_b_in # Both checked in — normal flow started, job is stale

      if team_a_in && !team_b_in
        apply_walkover(match, winner: match.team_a, loser: match.team_b)
      elsif team_b_in && !team_a_in
        apply_walkover(match, winner: match.team_b, loser: match.team_a)
      else
        # Neither checked in — double no-show, admin must decide
        match.update!(status: 'walkover')
        broadcast_update(match)
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    private

    def apply_walkover(match, winner:, loser:)
      BracketProgressionService.new(match, winner: winner, loser: loser, status: 'walkover').call
      broadcast_update(match)
    end

    def broadcast_update(match)
      ActionCable.server.broadcast(
        "tournament_#{match.tournament_id}",
        {
          match_id: match.id,
          status: match.status,
          team_a_score: match.team_a_score,
          team_b_score: match.team_b_score,
          updated_at: match.updated_at.iso8601,
          event: 'walkover'
        }
      )
    end
  end
end
