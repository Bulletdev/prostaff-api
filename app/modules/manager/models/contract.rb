# frozen_string_literal: true

# Represents a formal contract between an organization and a player or staff member.
#
# Player/coaching contracts reference a Player via player_id.
# Staff contracts reference a StaffMember via staff_member_id.
# Partnership contracts require neither assignee (sponsor, venue deal, etc.).
#
# @attr [String] contract_type player | staff | coaching | partnership
# @attr [String] status draft | pending_signature | active | expired | terminated | renewed
# @attr [Date] start_date Contract effective date
# @attr [Date] end_date Contract expiration date
# @attr [Decimal] base_salary Base compensation amount
# @attr [String] salary_period monthly | weekly | per_event
class Contract < ApplicationRecord
  include SoftDeletable

  TYPES    = %w[player staff coaching partnership].freeze
  STATUSES = %w[draft pending_signature active expired terminated renewed].freeze
  PERIODS  = %w[monthly weekly per_event].freeze

  PLAYER_TYPES     = %w[player].freeze
  STAFF_TYPES      = %w[staff coaching].freeze
  ASSIGNEE_TYPES   = (PLAYER_TYPES + STAFF_TYPES).freeze

  belongs_to :organization
  belongs_to :player,       optional: true
  belongs_to :staff_member, class_name: 'StaffMember', optional: true
  belongs_to :created_by,   class_name: 'User'
  belongs_to :updated_by,   class_name: 'User', optional: true
  belongs_to :renewed_from, class_name: 'Contract', optional: true

  has_many :bonuses, class_name: 'ContractBonus', dependent: :destroy
  has_many :renewals, class_name: 'Contract',
                      foreign_key: :renewed_from_id, dependent: :nullify, inverse_of: :renewed_from

  validates :contract_type, inclusion: { in: TYPES }
  validates :status,        inclusion: { in: STATUSES }
  validates :salary_period, inclusion: { in: PERIODS }
  validates :start_date, :end_date, :base_salary, presence: true
  validate  :assignee_present
  validate  :end_date_after_start_date
  validate  :no_overlapping_active_contract, on: :create, if: -> { status == 'active' }
  validate  :no_overlapping_draft_contract,  on: :create, if: -> { status == 'draft' }

  scope :active,   -> { where(status: 'active') }
  scope :expiring, lambda { |days = 30|
    where(status: 'active')
      .where(end_date: (Date.current)..(Date.current + days.days))
  }
  scope :expired, -> { where(status: 'expired') }

  # @return [Player, StaffMember, nil] the assigned entity for this contract
  def assignee
    player || staff_member
  end

  # @return [String, nil] display name of the assigned entity
  def assignee_name
    return player.professional_name.presence || player.summoner_name if player
    return staff_member.name if staff_member

    nil
  end

  # @return [Integer] days remaining (>= 0)
  def days_remaining
    return 0 if end_date <= Date.current

    (end_date - Date.current).to_i
  end

  # @param threshold [Integer] number of days (default: 30)
  # @return [Boolean]
  def expiring_soon?(threshold = 30)
    status == 'active' && days_remaining <= threshold
  end

  def soft_delete!
    update_columns(deleted_at: Time.current)
  end

  private

  def assignee_present
    return unless ASSIGNEE_TYPES.include?(contract_type)

    if PLAYER_TYPES.include?(contract_type) && player_id.nil?
      errors.add(:player_id, 'is required for player/coaching contracts')
    elsif STAFF_TYPES.include?(contract_type) && staff_member_id.nil?
      errors.add(:staff_member_id, 'is required for staff contracts')
    end
  end

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, 'must be after start date') if end_date <= start_date
  end

  def no_overlapping_active_contract
    scope = Contract.unscoped.active.where(organization_id: organization_id).where.not(id: id)
    if player_id
      scope = scope.where(player_id: player_id)
      errors.add(:base, 'Player already has an active contract') if scope.exists?
    elsif staff_member_id
      scope = scope.where(staff_member_id: staff_member_id)
      errors.add(:base, 'Staff member already has an active contract') if scope.exists?
    end
  end

  def no_overlapping_draft_contract
    scope = Contract.unscoped
                    .where(organization_id: organization_id, status: 'draft', deleted_at: nil)
                    .where.not(id: id)
    if player_id
      scope = scope.where(player_id: player_id)
      errors.add(:base, 'Player already has a draft contract') if scope.exists?
    elsif staff_member_id
      scope = scope.where(staff_member_id: staff_member_id)
      errors.add(:base, 'Staff member already has a draft contract') if scope.exists?
    end
  end
end
