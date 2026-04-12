# frozen_string_literal: true

# TournamentChannel — Real-time match status updates for a tournament.
#
# Broadcasts match state changes (checkin, score, status transitions, WO) to all
# subscribers watching a specific tournament. No auth required for read — subscription
# is open so spectators and participants can both follow live.
#
# Subscription params:
#   tournament_id [String] — UUID of the tournament to subscribe to
#
# Broadcast payload (from MatchConfirmationService, TournamentWalkoverJob, etc.):
#   {
#     match_id:     "uuid",
#     status:       "in_progress" | "awaiting_report" | "confirmed" | "walkover" | ...,
#     team_a_score: 0,
#     team_b_score: 0,
#     updated_at:   "2026-04-11T12:00:00Z",
#     event:        "checkin" | "report" | "confirmed" | "walkover" (optional)
#   }
#
# @example Frontend subscription
#   consumer.subscriptions.create(
#     { channel: 'TournamentChannel', tournament_id: 'uuid' },
#     { received: (data) => console.log(data) }
#   )
class TournamentChannel < ApplicationCable::Channel
  def subscribed
    tournament_id = params[:tournament_id]

    unless tournament_id.present? && Tournament.exists?(id: tournament_id)
      reject
      return
    end

    stream_from "tournament_#{tournament_id}"
    logger.info "[TournamentChannel] subscribed user=#{current_user&.id || 'anon'} tournament=#{tournament_id}"
  end

  def unsubscribed
    stop_all_streams
  end
end
