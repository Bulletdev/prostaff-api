# frozen_string_literal: true

# Handles dual-report validation for tournament matches.
#
# Flow:
#   1. Captain submits report (team_a_score, team_b_score, evidence_url)
#   2. MatchReport record created/updated for their team
#   3. If both teams have reported:
#      - Scores match  → status: confirmed → BracketProgressionService
#      - Scores differ → status: disputed (admin resolves via admin_resolve endpoint)
#   4. If only one team reported → status: awaiting_confirm
#
# @example
#   result = MatchConfirmationService.new(
#     match: tournament_match,
#     team: my_tournament_team,
#     user: current_user,
#     team_a_score: 2,
#     team_b_score: 1,
#     evidence_url: "https://..."
#   ).call
#   result[:status] # => :submitted | :confirmed | :disputed | :error
class MatchConfirmationService
  REPORT_DEADLINE_HOURS = 2

  def initialize(match:, team:, user:, team_a_score:, team_b_score:, evidence_url:)
    @match        = match
    @team         = team
    @user         = user
    @team_a_score = team_a_score.to_i
    @team_b_score = team_b_score.to_i
    @evidence_url = evidence_url
  end

  def call
    validate!

    ActiveRecord::Base.transaction do
      report = upsert_report!
      outcome = compare_reports(report)
      { status: outcome, report: report }
    end
  rescue ArgumentError => e
    { status: :error, message: e.message }
  end

  private

  def validate!
    raise ArgumentError, "Match is not open for reporting (status: #{@match.status})" unless @match.open_for_report?
    raise ArgumentError, 'Evidence screenshot is required' if @evidence_url.blank?
    raise ArgumentError, 'Team is not a participant in this match' unless participant?
  end

  def participant?
    [@match.team_a_id, @match.team_b_id].include?(@team.id)
  end

  def upsert_report!
    report = MatchReport.find_or_initialize_by(
      tournament_match: @match,
      tournament_team: @team
    )

    report.assign_attributes(
      team_a_score: @team_a_score,
      team_b_score: @team_b_score,
      evidence_url: @evidence_url,
      reported_by_user: @user,
      status: 'submitted',
      submitted_at: Time.current,
      deadline_at: report.deadline_at || REPORT_DEADLINE_HOURS.hours.from_now
    )

    report.save!
    report
  end

  def compare_reports(my_report)
    other_team = opponent_team
    other_report = MatchReport.find_by(tournament_match: @match, tournament_team: other_team)

    unless other_report&.submitted?
      # Still waiting for opponent
      @match.update!(status: 'awaiting_confirm')
      broadcast_update
      return :submitted
    end

    if my_report.scores_match?(other_report)
      confirm_match!(my_report, other_report)
      :confirmed
    else
      dispute_match!(my_report, other_report)
      :disputed
    end
  end

  def confirm_match!(my_report, other_report)
    winner, loser = determine_winner_loser

    my_report.update!(status: 'confirmed', confirmed_at: Time.current)
    other_report.update!(status: 'confirmed', confirmed_at: Time.current)

    @match.update!(
      team_a_score: @team_a_score,
      team_b_score: @team_b_score,
      status: 'confirmed'
    )

    BracketProgressionService.new(@match, winner: winner, loser: loser).call
    broadcast_update
    Events::EventPublisher.publish(
      user_id: @user.id,
      org_id: @user.organization_id,
      type: 'tournament_match.confirmed',
      payload: {
        match_id: @match.id,
        tournament_id: @match.tournament_id,
        team_a_score: @match.team_a_score,
        team_b_score: @match.team_b_score,
        winner_id: winner&.id
      }
    )
  end

  def dispute_match!(my_report, other_report)
    my_report.update!(status: 'disputed')
    other_report.update!(status: 'disputed')
    @match.update!(status: 'disputed')
    broadcast_update
  end

  def determine_winner_loser
    if @team_a_score > @team_b_score
      [@match.team_a, @match.team_b]
    else
      [@match.team_b, @match.team_a]
    end
  end

  def opponent_team
    if @match.team_a_id == @team.id
      @match.team_b
    else
      @match.team_a
    end
  end

  def broadcast_update
    ActionCable.server.broadcast(
      "tournament_#{@match.tournament_id}",
      {
        match_id: @match.id,
        status: @match.reload.status,
        team_a_score: @match.team_a_score,
        team_b_score: @match.team_b_score,
        updated_at: @match.updated_at.iso8601
      }
    )
  end
end
