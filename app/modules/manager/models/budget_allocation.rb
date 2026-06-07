# frozen_string_literal: true

# Represents a budget period for tracking organizational expenses.
#
# A budget allocation defines the total available budget for a given period
# (monthly, split, annual, or custom). Expenses are linked to allocations
# to track burn rate and remaining budget.
#
# @attr [String] name Descriptive name (e.g. "Season 2026 - Main Roster")
# @attr [String] period_type Period type: monthly, split, annual, or custom
# @attr [Date] start_date Budget period start
# @attr [Date] end_date Budget period end
# @attr [Decimal] total_budget Total budget amount
# @attr [String] status Status: active, closed, or draft
class BudgetAllocation < ApplicationRecord
  PERIOD_TYPES = %w[monthly split annual custom].freeze
  STATUSES     = %w[active closed draft].freeze

  belongs_to :organization
  belongs_to :created_by, class_name: 'User'

  has_many :expenses, dependent: :nullify

  validates :name,        presence: true
  validates :period_type, inclusion: { in: PERIOD_TYPES }
  validates :status,      inclusion: { in: STATUSES }
  validates :start_date, :end_date, :total_budget, presence: true
  validates :total_budget, numericality: { greater_than: 0 }
  validate  :end_date_after_start_date

  scope :active,  -> { where(status: 'active') }
  scope :draft,   -> { where(status: 'draft') }
  scope :closed,  -> { where(status: 'closed') }

  private

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, 'must be after start date') if end_date <= start_date
  end
end
