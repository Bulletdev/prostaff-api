# frozen_string_literal: true

# WebSocket channel for real-time draft analysis.
# Frontend connects with: { channel: 'DraftChannel', draft_id: '<id>' }
# Authentication is handled by ApplicationCable::Connection (JWT via ?token= query param).
#
# Security: draft_id is validated against the current user's organization.
# A user from org A cannot subscribe to org B's draft stream.
class DraftChannel < ApplicationCable::Channel
  def subscribed
    return if unauthorized_draft_subscription?

    stream_from "draft_#{current_org_id}_#{params[:draft_id]}"
    logger.info "[DraftChannel] user=#{current_user.id} subscribed to draft=#{params[:draft_id]}"
  end

  def unsubscribed
    stop_all_streams
  end

  # Client sends: { team_a: [...], team_b: [...] }
  def picks_updated(data)
    draft_id = params[:draft_id]
    return if draft_id.blank? || current_org_id.blank?

    team_a = data['team_a'].presence || []
    team_b = data['team_b'].presence || []

    return unless team_a.any? || team_b.any?

    result = DraftAnalyzer.call(team_a:, team_b:)

    ActionCable.server.broadcast("draft_#{current_org_id}_#{draft_id}", {
                                   type: 'ai_update',
                                   payload: DraftAnalysisBlueprint.render_as_hash(result)
                                 })
  end

  private

  def unauthorized_draft_subscription?
    draft_id = params[:draft_id]
    if draft_id.blank? || current_org_id.blank?
      reject
      return true
    end
    draft = DraftPlan.find_by(id: draft_id, organization_id: current_org_id)
    return false if draft

    logger.warn "[DraftChannel] user=#{current_user.id} unauthorized draft=#{draft_id}"
    reject
    true
  end
end
