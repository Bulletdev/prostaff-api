# frozen_string_literal: true

# A chronological update posted during an active incident.
# Each update advances the incident status and describes actions taken.
class StatusIncidentUpdate < ApplicationRecord
  STATUSES = StatusIncident::STATUSES

  belongs_to :status_incident, inverse_of: :updates

  belongs_to :created_by,
             class_name: 'User',
             foreign_key: :created_by_user_id,
             optional: true,
             inverse_of: false

  validates :body,   presence: true
  validates :status, inclusion: { in: STATUSES }
end
