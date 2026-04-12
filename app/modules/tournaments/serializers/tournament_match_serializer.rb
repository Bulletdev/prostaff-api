# frozen_string_literal: true

# Serializes a TournamentMatch with both team sides, scores, bracket positioning,
# and schedule timestamps.
class TournamentMatchSerializer
  def initialize(match, options = {})
    @match   = match
    @options = options
  end

  def as_json
    bracket_fields
      .merge(team_fields)
      .merge(schedule_fields)
  end

  private

  def bracket_fields
    {
      id: @match.id,
      tournament_id: @match.tournament_id,
      bracket_side: @match.bracket_side,
      round_label: @match.round_label,
      round_order: @match.round_order,
      match_number: @match.match_number,
      bo_format: @match.bo_format,
      status: @match.status,
      next_match_winner_id: @match.next_match_winner_id,
      next_match_loser_id: @match.next_match_loser_id
    }
  end

  def team_fields
    {
      team_a_id: @match.team_a_id,
      team_a_name: @match.team_a&.team_name,
      team_a_tag: @match.team_a&.team_tag,
      team_a_logo: @match.team_a&.logo_url,
      team_a_score: @match.team_a_score,
      team_b_id: @match.team_b_id,
      team_b_name: @match.team_b&.team_name,
      team_b_tag: @match.team_b&.team_tag,
      team_b_logo: @match.team_b&.logo_url,
      team_b_score: @match.team_b_score,
      winner_id: @match.winner_id,
      loser_id: @match.loser_id
    }
  end

  def schedule_fields
    {
      scheduled_at: @match.scheduled_at&.iso8601,
      checkin_opens_at: @match.checkin_opens_at&.iso8601,
      checkin_deadline_at: @match.checkin_deadline_at&.iso8601,
      wo_deadline_at: @match.wo_deadline_at&.iso8601,
      started_at: @match.started_at&.iso8601,
      completed_at: @match.completed_at&.iso8601
    }
  end
end
