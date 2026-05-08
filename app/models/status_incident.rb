# frozen_string_literal: true

# Represents a service incident affecting one or more components.
#
# Lifecycle: investigating -> identified -> monitoring -> resolved
# Severity tiers: minor (no SLA impact), major (degraded service), critical (full outage)
class StatusIncident < ApplicationRecord
  SEVERITIES = %w[minor major critical].freeze
  STATUSES   = %w[investigating identified monitoring resolved].freeze
  COMPONENTS = %w[api database redis websocket sidekiq riot_api].freeze

  belongs_to :created_by,
             class_name: 'User',
             foreign_key: :created_by_user_id,
             optional: true,
             inverse_of: false

  has_many :updates,
           class_name: 'StatusIncidentUpdate',
           foreign_key: :status_incident_id,
           dependent: :destroy,
           inverse_of: :status_incident

  validates :title,     presence: true
  validates :body,      presence: true
  validates :started_at, presence: true
  validates :severity,  inclusion: { in: SEVERITIES }
  validates :status,    inclusion: { in: STATUSES }
  validate  :affected_components_valid

  scope :active, -> { where.not(status: 'resolved') }
  scope :recent, -> { order(started_at: :desc) }

  def resolved?
    status == 'resolved'
  end

  private

  def affected_components_valid
    return if affected_components.blank?

    invalid = affected_components - COMPONENTS
    return if invalid.empty?

    errors.add(:affected_components, "contains invalid values: #{invalid.join(', ')}")
  end
end
