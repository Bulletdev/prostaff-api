# frozen_string_literal: true

# Represents a formal contract between an organization and a player or staff member.
#
# Contracts are the central entity of the Manager module. They track salary,
# validity dates, status transitions, and renewal chains. Soft-deleted records
# are retained for audit purposes and never physically removed.
#
# @attr [String] contract_type Type of contract: player, staff, coaching, or partnership
# @attr [String] status Lifecycle status: draft, pending_signature, active, expired,
#   terminated, or renewed
# @attr [Date] start_date Contract effective date
# @attr [Date] end_date Contract expiration date
# @attr [Decimal] base_salary Base compensation amount
# @attr [String] salary_period Compensation frequency: monthly, weekly, or per_event
class Contract < ApplicationRecord
  include SoftDeletable

  TYPES    = %w[player staff coaching partnership].freeze
  STATUSES = %w[draft pending_signature active expired terminated renewed].freeze
  PERIODS  = %w[monthly weekly per_event].freeze

  belongs_to :organization
  belongs_to :player
  belongs_to :created_by, class_name: 'User'
  belongs_to :updated_by, class_name: 'User', optional: true
  belongs_to :renewed_from, class_name: 'Contract', optional: true

  has_many :bonuses, class_name: 'ContractBonus', dependent: :destroy
  has_many :renewals, class_name: 'Contract',
                      foreign_key: :renewed_from_id, dependent: :nullify, inverse_of: :renewed_from

  validates :contract_type, inclusion: { in: TYPES }
  validates :status,        inclusion: { in: STATUSES }
  validates :salary_period, inclusion: { in: PERIODS }
  validates :start_date, :end_date, :base_salary, presence: true
  validate  :end_date_after_start_date
  validate  :no_overlapping_active_contract, on: :create, if: -> { status == 'active' }
  validate  :no_overlapping_draft_contract,  on: :create, if: -> { status == 'draft' }

  scope :active,   -> { where(status: 'active') }
  scope :expiring, lambda { |days = 30|
    where(status: 'active')
      .where(end_date: (Date.current)..(Date.current + days.days))
  }
  scope :expired, -> { where(status: 'expired') }

  # Returns the number of days remaining until contract expiration.
  # Returns 0 when the contract has already expired.
  # @return [Integer] days remaining (>= 0)
  def days_remaining
    return 0 if end_date <= Date.current

    (end_date - Date.current).to_i
  end

  # Returns true when the contract is active and expires within the given threshold.
  # A contract expiring today (days_remaining == 0) is considered critical and satisfies
  # the check regardless of threshold.
  # @param threshold [Integer] number of days (default: 30)
  # @return [Boolean]
  def expiring_soon?(threshold = 30)
    status == 'active' && days_remaining <= threshold
  end

  # Override SoftDeletable to not update :status, which has its own valid transitions.
  # @return [Boolean]
  def soft_delete!
    update_columns(deleted_at: Time.current)
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, 'must be after start date') if end_date <= start_date
  end

  def no_overlapping_active_contract
    overlap = Contract.unscoped
                      .active
                      .where(player_id: player_id, organization_id: organization_id)
                      .where.not(id: id)
                      .exists?
    errors.add(:base, 'Player already has an active contract') if overlap
  end

  def no_overlapping_draft_contract
    overlap = Contract.unscoped
                      .where(player_id: player_id, organization_id: organization_id,
                             status: 'draft', deleted_at: nil)
                      .where.not(id: id)
                      .exists?
    errors.add(:base, 'Player already has a draft contract') if overlap
  end
end
