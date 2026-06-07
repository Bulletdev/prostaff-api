# frozen_string_literal: true

# Represents a performance or milestone bonus clause attached to a contract.
#
# Bonuses can be for performance, tournament results, signing, retention, or other
# criteria. Status transitions go from pending to achieved and then paid.
#
# @attr [String] bonus_type Category: performance, tournament, signing, retention, or other
# @attr [String] trigger Human-readable condition description (e.g. "win_rate >= 60%")
# @attr [Decimal] amount Bonus amount
# @attr [String] status Lifecycle: pending, achieved, paid, or cancelled
class ContractBonus < ApplicationRecord
  self.table_name = 'contract_bonuses'

  TYPES    = %w[performance tournament signing retention other].freeze
  STATUSES = %w[pending achieved paid cancelled].freeze

  belongs_to :contract
  belongs_to :organization

  validates :bonus_type, inclusion: { in: TYPES }
  validates :status,     inclusion: { in: STATUSES }
  validates :trigger, :amount, presence: true
  validates :amount, numericality: { greater_than: 0 }

  scope :pending,   -> { where(status: 'pending') }
  scope :achieved,  -> { where(status: 'achieved') }
  scope :paid,      -> { where(status: 'paid') }
end
