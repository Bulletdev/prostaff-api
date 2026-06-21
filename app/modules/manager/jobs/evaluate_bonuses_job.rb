# frozen_string_literal: true

module Manager
  # Nightly job that auto-evaluates structured contract bonuses.
  #
  # For each pending ContractBonus with metric_key, comparator, and threshold set,
  # and whose evaluation window is currently active:
  #   1. Resolves the current metric value via Goals::MetricResolver.
  #   2. Evaluates the comparator against the threshold.
  #   3. Marks the bonus as 'achieved' when the condition is satisfied.
  #
  # Individual bonus failures are rescued and logged so one error does not
  # abort the entire batch.
  #
  # @example Manual trigger from Rails console
  #   Manager::EvaluateBonusesJob.new.perform
  class EvaluateBonusesJob
    include Sidekiq::Job

    sidekiq_options queue: 'default', retry: 3

    # Adapter to feed ContractBonus data into Goals::MetricResolver
    # without modifying the resolver's interface.
    BonusResolverAdapter = Struct.new(
      :player, :metric_key, :start_date, :due_date, :end_date,
      keyword_init: true
    )

    # @return [void]
    def perform
      Rails.logger.info('[EvaluateBonusesJob] Starting bonus evaluation')

      count = { evaluated: 0, skipped: 0, errors: 0 }

      Current.skip_organization_scope = true
      evaluable_bonuses.each do |bonus|
        evaluate_bonus(bonus, count)
      end
    ensure
      Current.skip_organization_scope = false
      Rails.logger.info(
        "[EvaluateBonusesJob] Done — evaluated=#{count[:evaluated]} " \
        "skipped=#{count[:skipped]} errors=#{count[:errors]}"
      )
    end

    private

    # Returns pending bonuses that have structured evaluation fields populated.
    # @return [ActiveRecord::Relation]
    def evaluable_bonuses
      ContractBonus
        .pending
        .where.not(metric_key: [nil, ''])
        .where.not(comparator: [nil, ''])
        .where.not(threshold: nil)
        .includes(contract: :player)
    end

    # Evaluates a single bonus and updates count in place.
    # @param bonus [ContractBonus]
    # @param count [Hash]
    # @return [void]
    def evaluate_bonus(bonus, count)
      unless bonus.window_active?
        count[:skipped] += 1
        return
      end

      player = bonus.contract&.player
      unless player
        count[:skipped] += 1
        return
      end

      value = resolve_metric(bonus, player)
      unless value
        count[:skipped] += 1
        return
      end

      if comparator_satisfied?(bonus, value)
        bonus.update!(status: 'achieved', achieved_at: Date.current)
        count[:evaluated] += 1
      else
        count[:skipped] += 1
      end
    rescue StandardError => e
      count[:errors] += 1
      Rails.logger.error("[EvaluateBonusesJob] bonus=#{bonus.id} error=#{e.class}: #{e.message}")
    end

    # Resolves the metric value for a bonus using Goals::MetricResolver.
    # @param bonus [ContractBonus]
    # @param player [Player]
    # @return [Float, nil]
    def resolve_metric(bonus, player)
      adapter = BonusResolverAdapter.new(
        player: player,
        metric_key: bonus.metric_key,
        start_date: bonus.window_start,
        due_date: bonus.window_end,
        end_date: bonus.window_end
      )
      Goals::MetricResolver.new(adapter).resolve
    end

    # Returns true when the resolved value satisfies the bonus comparator.
    # @param bonus [ContractBonus]
    # @param value [Numeric]
    # @return [Boolean]
    def comparator_satisfied?(bonus, value)
      target = bonus.threshold.to_f
      case bonus.comparator
      when 'gte' then value.to_f >= target
      when 'lte' then value.to_f <= target
      when 'eq'  then value.to_f == target
      else false
      end
    end
  end
end
