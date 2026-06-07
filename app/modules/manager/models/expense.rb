# frozen_string_literal: true

# Represents a financial expense within an organization.
#
# Expenses can be linked to a budget allocation, a player (for salary/bonus
# payments), or be organizational-level costs. Status flows from pending to
# approved and then paid.
#
# @attr [String] category Type: salary, bonus, bootcamp, travel, equipment,
#   housing, media, tournament_fee, insurance, or other
# @attr [String] description Human-readable description of the expense
# @attr [Decimal] amount Expense amount
# @attr [Date] expense_date Date the expense was incurred
# @attr [String] status Approval status: pending, approved, paid, rejected, or reimbursed
class Expense < ApplicationRecord
  CATEGORIES = %w[
    salary bonus bootcamp travel equipment
    housing media tournament_fee insurance other
  ].freeze

  STATUSES = %w[pending approved paid rejected reimbursed].freeze

  belongs_to :organization
  belongs_to :budget_allocation, optional: true
  belongs_to :created_by,  class_name: 'User'
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :player,      optional: true

  validates :category,     inclusion: { in: CATEGORIES }
  validates :status,       inclusion: { in: STATUSES }
  validates :amount,       numericality: { greater_than: 0 }
  validates :expense_date, :description, presence: true

  scope :by_category, ->(cat) { where(category: cat) }
  scope :by_period,   ->(from, to) { where(expense_date: (from)..(to)) }
  scope :salary,      -> { where(category: 'salary') }
  scope :non_salary,  -> { where.not(category: 'salary') }
  scope :paid,        -> { where(status: 'paid') }
  scope :pending,     -> { where(status: 'pending') }
end
