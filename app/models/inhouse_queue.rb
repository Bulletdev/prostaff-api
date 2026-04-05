# frozen_string_literal: true

# Represents a role-based queue for an inhouse session.
# Players join the queue by role (max 2 per role, 10 total).
# Once full and checked-in, a coach starts the session from this queue.
#
# Lifecycle: open → check_in → closed
#
class InhouseQueue < ApplicationRecord
  ROLES     = %w[top jungle mid adc support].freeze
  MAX_SLOTS = 10 # 5 roles × 2 players

  belongs_to :organization
  belongs_to :created_by, class_name: 'User', foreign_key: :created_by_user_id
  has_many   :inhouse_queue_entries, dependent: :destroy
  has_many   :players, through: :inhouse_queue_entries

  enum :status, { open: 'open', check_in: 'check_in', closed: 'closed' }, prefix: false

  scope :active, -> { where(status: %w[open check_in]) }
  scope :recent, -> { order(created_at: :desc) }

  validates :status, presence: true, inclusion: { in: statuses.keys }

  def full?
    inhouse_queue_entries.size >= MAX_SLOTS
  end

  def slots_for_role(role)
    inhouse_queue_entries.where(role: role).count
  end

  def checked_in_entries
    inhouse_queue_entries.where(checked_in: true)
  end

  def serialize(detailed: false)
    result = {
      id: id,
      status: status,
      check_in_deadline: check_in_deadline,
      total_entries: inhouse_queue_entries.size,
      total_slots: MAX_SLOTS,
      full: full?,
      created_at: created_at
    }

    merge_detailed_fields(result) if detailed
    result
  end

  private

  def merge_detailed_fields(result)
    loaded = inhouse_queue_entries.includes(:player)
    by_role = loaded.group_by(&:role)
    result[:entries_by_role] = ROLES.index_with { |role| (by_role[role] || []).map(&:serialize) }
    result[:entries] = loaded.map(&:serialize)
  end
end
