# frozen_string_literal: true

# Represents a non-player staff member of an organization (coaches, analysts, support staff).
#
# @attr [String] name         Full name
# @attr [String] role         Job role (head_coach, analyst, psychologist, etc.)
# @attr [String] status       Employment status: active, inactive, on_leave, terminated
# @attr [String] line         Team tier this staff member works with: main, academy, reserve
# @attr [String] country      ISO 3166-1 alpha-2 country code
# @attr [Date]   birth_date
# @attr [Date]   contract_start_date  Denormalized for quick queries
# @attr [Date]   contract_end_date    Denormalized for quick queries
class StaffMember < ApplicationRecord
  ROLES = %w[
    head_coach assistant_coach analyst video_analyst
    psychologist physical_trainer nutritionist
    team_manager content_creator scout other
  ].freeze

  STATUSES = %w[active inactive on_leave terminated].freeze
  LINES    = %w[main academy reserve].freeze

  belongs_to :organization
  has_one :contract, dependent: :nullify

  validates :name,            presence: true
  validates :role,            inclusion: { in: ROLES }
  validates :status,          inclusion: { in: STATUSES }
  validates :line,            inclusion: { in: LINES }, allow_nil: true
  validates :organization_id, presence: true

  scope :active,      -> { where(status: 'active') }
  scope :not_deleted, -> { where(deleted_at: nil) }

  # Soft-deletes the staff member by setting deleted_at and status to terminated.
  # Uses update_columns to bypass callbacks and validations.
  # @return [Boolean]
  def soft_delete!
    update_columns(deleted_at: Time.current, status: 'terminated')
  end

  # Returns true when this staff member has been soft-deleted.
  # @return [Boolean]
  def deleted?
    deleted_at.present?
  end
end
