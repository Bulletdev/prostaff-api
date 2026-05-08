# frozen_string_literal: true

# Handles submission and cross-validation of scrim series results.
#
# Each organization reports their own game-by-game outcomes:
#   ["win","loss","win"]  → they won 2-1
#
# The opponent's mirror should be:
#   ["loss","win","loss"] → they lost 2-1
#
# When both reports are in, the service compares them game by game.
# A match confirms the result. A mismatch triggers a dispute.
# After MAX_ATTEMPTS disputes, the confrontation is marked unresolvable.
#
# @example
#   result = ScrimResultValidationService.new(
#     scrim_request: request,
#     organization:  current_org,
#     game_outcomes: ["win","loss","win"]
#   ).call
#
#   result[:status] # => :confirmed | :reported | :disputed | :unresolvable | :error
class ScrimResultValidationService
  attr_reader :scrim_request, :organization, :game_outcomes

  def initialize(scrim_request:, organization:, game_outcomes:)
    @scrim_request = scrim_request
    @organization  = organization
    @game_outcomes = game_outcomes
  end

  def call
    validate_inputs!

    ActiveRecord::Base.transaction do
      report = upsert_report!
      outcome = compare_with_opponent(report)
      { status: outcome, report: report }
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    { status: :error, message: e.message }
  end

  private

  def validate_inputs!
    raise ArgumentError, 'game_outcomes must be an array of "win"/"loss"' unless game_outcomes.is_a?(Array)
    raise ArgumentError, 'game_outcomes cannot be empty' if game_outcomes.empty?

    unless game_outcomes.all? { |o| %w[win loss].include?(o) }
      raise ArgumentError, 'Each outcome must be "win" or "loss"'
    end

    planned = scrim_request.games_planned.to_i
    return unless planned.positive? && game_outcomes.length != planned

    raise ArgumentError, "Expected #{planned} outcomes, got #{game_outcomes.length}"
  end

  def upsert_report!
    report = ScrimResultReport.find_or_initialize_by(
      scrim_request: scrim_request,
      organization: organization
    )

    if report.persisted? && report.attempt_count >= ScrimResultReport::MAX_ATTEMPTS
      raise ArgumentError, 'Maximum reporting attempts (3) exceeded. Result marked unresolvable.'
    end

    deadline = if scrim_request.proposed_at.present?
                 [scrim_request.proposed_at, Time.current].max + ScrimResultReport::DEADLINE_DAYS.days
               else
                 Time.current + ScrimResultReport::DEADLINE_DAYS.days
               end

    report.assign_attributes(
      game_outcomes: game_outcomes,
      status: 'reported',
      reported_at: Time.current,
      deadline_at: report.new_record? ? deadline : report.deadline_at,
      attempt_count: report.attempt_count + 1
    )
    report.save!
    report
  end

  def compare_with_opponent(my_report)
    opponent_report = ScrimResultReport.find_by(
      scrim_request: scrim_request,
      organization_id: opponent_org_id
    )

    # Opponent hasn't reported yet — just wait
    return :reported unless opponent_report&.reported_at?

    if mirrored?(my_report.game_outcomes, opponent_report.game_outcomes)
      confirm_both!(my_report, opponent_report)
      :confirmed
    else
      handle_dispute!(my_report, opponent_report)
    end
  end

  # Checks that every game has exactly opposing outcomes (win↔loss)
  def mirrored?(outcomes_a, outcomes_b)
    return false if outcomes_a.length != outcomes_b.length

    outcomes_a.zip(outcomes_b).all? do |a, b|
      (a == 'win' && b == 'loss') || (a == 'loss' && b == 'win')
    end
  end

  def confirm_both!(report_a, report_b)
    now = Time.current
    report_a.update!(status: 'confirmed', confirmed_at: now)
    report_b.update!(status: 'confirmed', confirmed_at: now)
  end

  def handle_dispute!(report_a, report_b)
    max = ScrimResultReport::MAX_ATTEMPTS

    if report_a.attempt_count >= max || report_b.attempt_count >= max
      report_a.update!(status: 'unresolvable')
      report_b.update!(status: 'unresolvable')
      :unresolvable
    else
      report_a.update!(status: 'disputed')
      report_b.update!(status: 'disputed')
      :disputed
    end
  end

  def opponent_org_id
    if scrim_request.requesting_organization_id == organization.id
      scrim_request.target_organization_id
    else
      scrim_request.requesting_organization_id
    end
  end
end
