# frozen_string_literal: true

# WebSocket channel for real-time draft analysis.
# Frontend connects with: { channel: 'DraftChannel', draft_id: '<id>' }
# Authentication is handled by ApplicationCable::Connection (JWT via ?token= query param).
#
# Security: draft_id is validated against the current user's organization.
# A user from org A cannot subscribe to org B's draft stream.
class DraftChannel < ApplicationCable::Channel
  def subscribed
    # ActionCable channels do not go through authenticate_request!, so
    # Current.organization_id must be set manually for OrganizationScoped models.
    Current.organization_id = current_org_id

    return if unauthorized_draft_subscription?

    stream_from "draft_#{current_org_id}_#{params[:draft_id]}"
    logger.info "[DraftChannel] user=#{current_user&.id || current_player&.id} subscribed to draft=#{params[:draft_id]}"
  end

  def unsubscribed
    stop_all_streams
  end

  # Client sends: { team_a: [...], team_b: [...], patch: "16.08", league: "CBLOL" }
  def picks_updated(data)
    return unless valid_picks_context?

    team_a = Array(data['team_a'])
    team_b = Array(data['team_b'])
    return unless team_a.any? || team_b.any?

    broadcast_ai_update(params[:draft_id], team_a, team_b, data['patch'])
  rescue StandardError => e
    Rails.logger.error "[DraftChannel] picks_updated error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  private

  def valid_picks_context?
    params[:draft_id].present? && current_org_id.present?
  end

  def broadcast_ai_update(draft_id, team_a, team_b, patch)
    draft_result    = DraftAnalyzer.call(team_a:, team_b:, patch:)
    synergy_data    = fetch_synergy_data(team_a)
    top_synergies   = resolve_top_synergies(synergy_data, draft_result)
    top_counters    = resolve_top_counters(draft_result)
    patch_win_rates = fetch_patch_win_rates(team_a, team_b, patch)

    publish_ai_update(draft_id, draft_result, top_synergies, top_counters, patch_win_rates)
  end

  def publish_ai_update(draft_id, draft_result, top_synergies, top_counters, patch_win_rates)
    ActionCable.server.broadcast(
      "draft_#{current_org_id}_#{draft_id}",
      type: 'ai_update',
      payload: {
        win_probability: draft_result.win_probability,
        confidence: draft_result.confidence,
        source: draft_result.source,
        low_sample: draft_result.low_sample,
        top_synergies: top_synergies,
        top_counters: top_counters,
        suggested_picks: draft_result.suggested_picks || [],
        patch_win_rates: patch_win_rates
      }
    )
  end

  def fetch_synergy_data(team_a)
    if team_a.size >= 2
      SynergyMatrixService.call(champions: team_a)
    else
      { champions: team_a, matrix: [], top_pairs: [], weakest_pairs: [] }
    end
  end

  def resolve_top_synergies(synergy_data, draft_result)
    if synergy_data[:top_pairs].any?
      synergy_data[:top_pairs].first(5).map { |entry| { pair: entry[:pair], score: entry[:score] } }
    else
      (draft_result.synergy_scores || {})
        .sort_by { |_, val| -val[:score].to_f }
        .first(5)
        .map { |(champ_a, champ_b), val| { pair: [champ_a, champ_b], score: val[:score] } }
    end
  end

  def resolve_top_counters(draft_result)
    (draft_result.counter_scores || {})
      .sort_by { |_, val| -val[:advantage].to_f.abs }
      .first(5)
      .map { |(champ_a, champ_b), val| { matchup: [champ_a, champ_b], advantage: val[:advantage], games: val[:games] } }
  end

  def fetch_patch_win_rates(team_a, team_b, patch)
    return {} unless patch.present?

    ChampionWinrateService.bulk_lookup((team_a + team_b).uniq, patch)
  end

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
