# frozen_string_literal: true

# Serializes a MatchReport for a tournament match result submission.
class MatchReportSerializer
  def initialize(report, options = {})
    @report  = report
    @options = options
  end

  def as_json
    return nil unless @report

    {
      id: @report.id,
      tournament_match_id: @report.tournament_match_id,
      tournament_team_id: @report.tournament_team_id,
      team_a_score: @report.team_a_score,
      team_b_score: @report.team_b_score,
      evidence_url: @report.evidence_url,
      status: @report.status,
      submitted_at: @report.submitted_at&.iso8601,
      confirmed_at: @report.confirmed_at&.iso8601,
      deadline_at: @report.deadline_at&.iso8601
    }
  end
end
