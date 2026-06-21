# frozen_string_literal: true

module Goals
  # Nightly job that auto-evaluates active goals with a metric_key set.
  #
  # For each evaluable goal (status not terminal, metric_key present, assignable_type Player):
  #   1. Calls MetricResolver to get the current metric value.
  #   2. Creates a GoalCheckIn(source: auto) with the measured value.
  #   3. Updates team_goal.current_value (denormalized cache for list views).
  #   4. Recomputes status via comparator + due_date proximity.
  #   5. Fires an Event on transition into at_risk or missed.
  #
  # Individual goal failures are rescued and logged so one bad goal does not
  # abort the entire batch.
  #
  # @example Manual trigger from Rails console
  #   Goals::EvaluateGoalsJob.new.perform
  class EvaluateGoalsJob
    include Sidekiq::Job

    sidekiq_options queue: 'default', retry: 3

    def perform
      Rails.logger.info('[EvaluateGoalsJob] Starting nightly evaluation')

      count = { evaluated: 0, skipped: 0, errors: 0 }

      Current.skip_organization_scope = true
      TeamGoal.evaluable.includes(:player, :organization).find_each do |goal|
        evaluate_goal(goal, count)
      end
    ensure
      Current.skip_organization_scope = false

      Rails.logger.info(
        "[EvaluateGoalsJob] Done — evaluated=#{count[:evaluated]} " \
        "skipped=#{count[:skipped]} errors=#{count[:errors]}"
      )
    end

    private

    def evaluate_goal(goal, count)
      value = Goals::MetricResolver.new(goal).resolve

      unless value
        count[:skipped] += 1
        return
      end

      previous_status = goal.status
      record_check_in(goal, value)
      new_status = compute_status(goal, value)
      goal.update!(current_value: value, status: new_status)
      count[:evaluated] += 1

      notify_if_critical(goal, previous_status, new_status)
    rescue StandardError => e
      count[:errors] += 1
      Rails.logger.error("[EvaluateGoalsJob] goal=#{goal.id} error=#{e.class}: #{e.message}")
    end

    def record_check_in(goal, value)
      GoalCheckIn.create!(
        team_goal: goal,
        organization: goal.organization,
        measured_value: value,
        source: 'auto'
      )
    end

    # Determines the new status based on comparator satisfaction and due_date.
    def compute_status(goal, value)
      return 'met' if comparator_satisfied?(goal, value)

      due = goal.due_date
      return 'missed' if due && due < Date.current
      return 'at_risk' if due && (due.to_date - Date.current).to_i <= 7

      'on_track'
    end

    def comparator_satisfied?(goal, value)
      return false if goal.target_value.blank?

      comparator = goal.comparator.presence || 'gte'
      target     = goal.target_value.to_f

      case comparator
      when 'gte' then value.to_f >= target
      when 'lte' then value.to_f <= target
      when 'eq'  then (value.to_f - target).abs < Float::EPSILON
      else false
      end
    end

    # Publishes an event only on the first transition into at_risk or missed.
    def notify_if_critical(goal, previous_status, new_status)
      return unless %w[at_risk missed].include?(new_status)
      return if previous_status == new_status

      Events::EventPublisher.publish(
        user_id: goal.created_by_id || goal.organization.users.first&.id || 'system',
        org_id: goal.organization_id,
        type: "team_goal.#{new_status}",
        payload: critical_event_payload(goal, new_status)
      )
    rescue StandardError => e
      Rails.logger.warn("[EvaluateGoalsJob] Event publish failed goal=#{goal.id} error=#{e.message}")
    end

    def critical_event_payload(goal, new_status)
      { goal_id: goal.id, title: goal.title, player_id: goal.player_id,
        metric_key: goal.metric_key, status: new_status }
    end
  end
end
