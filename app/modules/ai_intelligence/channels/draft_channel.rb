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
    draft_id = params[:draft_id]
    return if draft_id.blank? || current_org_id.blank?

    team_a = Array(data['team_a'])
    team_b = Array(data['team_b'])
    patch  = data['patch']
    league = data['league']

    return unless team_a.any? || team_b.any?

    # 1. Win probability + counters + suggestions: DraftAnalyzer (ML first, Ruby fallback)
    draft_result = DraftAnalyzer.call(team_a:, team_b:, patch:)

    # 2. Sinergia via embeddings: SynergyMatrixService quando team_a tem >= 2 picks
    synergy_data = if team_a.size >= 2
                     SynergyMatrixService.call(champions: team_a)
                   else
                     { champions: team_a, matrix: [], top_pairs: [], weakest_pairs: [] }
                   end

    # 3. top_synergies — prefere embedding pairs, cai para synergy_scores do DraftAnalyzer
    top_synergies = if synergy_data[:top_pairs].any?
                      synergy_data[:top_pairs].first(5).map do |p|
                        { pair: p[:pair], score: p[:score] }
                      end
                    else
                      (draft_result.synergy_scores || {})
                        .sort_by { |_, v| -v[:score].to_f }
                        .first(5)
                        .map { |(a, b), v| { pair: [a, b], score: v[:score] } }
                    end

    # 4. top_counters — do DraftAnalyzer
    top_counters = (draft_result.counter_scores || {})
                   .sort_by { |_, v| -v[:advantage].to_f.abs }
                   .first(5)
                   .map { |(a, b), v| { matchup: [a, b], advantage: v[:advantage], games: v[:games] } }

    # 5. Patch win rates para todos os campeões envolvidos
    all_champions  = (team_a + team_b).uniq
    patch_win_rates = patch.present? ? ChampionWinrateService.bulk_lookup(all_champions, patch) : {}

    ActionCable.server.broadcast(
      "draft_#{current_org_id}_#{draft_id}",
      type: 'ai_update',
      payload: {
        win_probability:  draft_result.win_probability,
        confidence:       draft_result.confidence,
        source:           draft_result.source,
        low_sample:       draft_result.low_sample,
        top_synergies:    top_synergies,
        top_counters:     top_counters,
        suggested_picks:  draft_result.suggested_picks || [],
        patch_win_rates:  patch_win_rates
      }
    )
  rescue => e
    Rails.logger.error "[DraftChannel] picks_updated error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
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
