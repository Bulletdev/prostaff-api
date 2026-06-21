# frozen_string_literal: true

# Represents a performance or milestone bonus clause attached to a contract.
#
# Bonuses can be for performance, tournament results, signing, retention, or other
# criteria. Status transitions go from pending to achieved and then paid.
#
# Structured bonuses (with metric_key, comparator, and threshold) are evaluated
# automatically by Manager::EvaluateBonusesJob using Goals::MetricResolver.
#
# @attr [String] bonus_type Category: performance, tournament, signing, retention, or other
# @attr [String] trigger Human-readable condition description (e.g. "win_rate >= 60%")
# @attr [Decimal] amount Bonus amount
# @attr [String] status Lifecycle: pending, achieved, paid, or cancelled
# @attr [String] metric_key Optional metric key for auto-evaluation
# @attr [String] comparator Comparison operator: gte, lte, or eq
# @attr [Decimal] threshold Target value for the metric
# @attr [String] evaluation_window Window type: split, season, or custom
# @attr [Date] window_start Start of evaluation window
# @attr [Date] window_end End of evaluation window
class ContractBonus < ApplicationRecord
  self.table_name = 'contract_bonuses'

  TYPES        = %w[performance tournament signing retention other].freeze
  STATUSES     = %w[pending achieved paid cancelled].freeze
  COMPARATORS  = %w[gte lte eq].freeze
  EVAL_WINDOWS = %w[split season custom].freeze

  belongs_to :contract
  belongs_to :organization

  validates :bonus_type,  inclusion: { in: TYPES }
  validates :status,      inclusion: { in: STATUSES }
  validates :trigger, :amount, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :comparator,        inclusion: { in: COMPARATORS },  allow_blank: true
  validates :evaluation_window, inclusion: { in: EVAL_WINDOWS }, allow_blank: true
  validate  :validate_structured_bonus_fields

  scope :pending,   -> { where(status: 'pending') }
  scope :achieved,  -> { where(status: 'achieved') }
  scope :paid,      -> { where(status: 'paid') }

  # Returns true when all fields required for auto-evaluation are present
  # and the current date falls within the evaluation window.
  # @return [Boolean]
  def auto_evaluable?
    metric_key.present? && comparator.present? && threshold.present? && window_active?
  end

  # Returns true when the current date is within [window_start, window_end].
  # @return [Boolean]
  def window_active?
    return false unless window_start && window_end

    Date.current.between?(window_start, window_end)
  end

  private

  def validate_structured_bonus_fields
    return if metric_key.blank?

    errors.add(:metric_key, 'is not a valid metric key') unless Goals::MetricRegistry.valid?(metric_key)
    errors.add(:comparator, 'is required when metric_key is set') if comparator.blank?
    errors.add(:threshold, 'is required when metric_key is set') if threshold.blank?
  end
end
