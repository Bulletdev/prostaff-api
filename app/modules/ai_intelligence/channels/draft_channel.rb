# frozen_string_literal: true

# WebSocket channel for real-time draft analysis.
# Frontend connects with: { channel: 'DraftChannel', draft_id: '<id>' }
# Authentication is handled by ApplicationCable::Connection (JWT via ?token= query param).
class DraftChannel < ApplicationCable::Channel
  def subscribed
    draft_id = params[:draft_id]
    reject and return if draft_id.blank?

    stream_from "draft_#{draft_id}"
  end

  def unsubscribed
    stop_all_streams
  end

  # Client sends: { team_a: [...], team_b: [...] }
  def picks_updated(data)
    team_a = data['team_a'].presence || []
    team_b = data['team_b'].presence || []

    return unless team_a.any? || team_b.any?

    result = DraftAnalyzer.call(team_a:, team_b:)

    ActionCable.server.broadcast("draft_#{params[:draft_id]}", {
                                   type: 'ai_update',
                                   payload: DraftAnalysisBlueprint.render_as_hash(result)
                                 })
  end
end
