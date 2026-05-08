# frozen_string_literal: true

# ScoutingWatchlist represents an organization's interest in a scouting target
#
# This is the org-specific layer on top of global scouting targets.
# Each organization can track players independently with their own notes,
# priorities, and status tracking.
#
# @attr [UUID] organization_id The organization tracking this player
# @attr [UUID] scouting_target_id The global scouting target being tracked
# @attr [UUID] added_by_id User who added this to watchlist
# @attr [UUID] assigned_to_id Scout/coach assigned to track this player
# @attr [String] priority Priority level (low, medium, high, critical)
# @attr [String] status Tracking status (watching, contacted, negotiating, rejected, signed)
# @attr [Text] notes Organization's private notes about the player
# @attr [DateTime] last_reviewed When this was last reviewed by the org
# @attr [JSONB] metadata Additional org-specific metadata
class ScoutingWatchlist < ApplicationRecord
  # Concerns
  include OrganizationScoped
  include Constants

  # Associations
  belongs_to :organization
  belongs_to :scouting_target
  belongs_to :added_by, class_name: 'User'
  belongs_to :assigned_to, class_name: 'User', optional: true

  # Validations
  validates :priority, inclusion: { in: Constants::ScoutingTarget::PRIORITIES }
  validates :status, inclusion: { in: Constants::ScoutingTarget::STATUSES }
  validates :organization_id, uniqueness: { scope: :scouting_target_id }

  # Callbacks
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :high_priority, -> { where(priority: %w[high critical]) }
  scope :active, -> { where(status: %w[watching contacted negotiating]) }
  scope :needs_review, -> { where('last_reviewed IS NULL OR last_reviewed < ?', 1.week.ago) }
  scope :assigned_to_user, ->(user_id) { where(assigned_to_id: user_id) }

  # Instance methods

  def needs_review?
    last_reviewed.blank? || last_reviewed < 1.week.ago
  end

  def days_since_review
    return 'Never' if last_reviewed.blank?

    days = (Date.current - last_reviewed.to_date).to_i
    case days
    when 0 then 'Today'
    when 1 then 'Yesterday'
    else "#{days} days ago"
    end
  end

  def mark_as_reviewed!(user = nil)
    update!(
      last_reviewed: Time.current,
      assigned_to: user || assigned_to
    )
  end

  def advance_status!
    new_status = case status
                 when 'watching' then 'contacted'
                 when 'contacted' then 'negotiating'
                 when 'negotiating' then 'signed'
                 else status
                 end

    update!(status: new_status, last_reviewed: Time.current)
  end

  def priority_score
    case priority
    when 'low' then 1
    when 'medium' then 2
    when 'high' then 3
    when 'critical' then 4
    else 0
    end
  end

  def priority_color
    case priority
    when 'medium' then 'blue'
    when 'high' then 'orange'
    when 'critical' then 'red'
    else 'gray'
    end
  end

  def status_color
    case status
    when 'watching' then 'blue'
    when 'contacted' then 'yellow'
    when 'negotiating' then 'orange'
    when 'rejected' then 'red'
    when 'signed' then 'green'
    else 'gray'
    end
  end

  private

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      action: 'update',
      entity_type: 'ScoutingWatchlist',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end
end
