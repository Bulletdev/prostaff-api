# frozen_string_literal: true

# DraftSimulation model
# Stores live draft simulator state per game within a series
# series_id is a nanoid generated on the frontend; each game in the series is a separate record
class DraftSimulation < ApplicationRecord
  # Concerns
  include OrganizationScoped

  # Associations
  belongs_to :organization

  # Validations
  validates :series_id, presence: true
  validates :game_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :our_side, inclusion: { in: %w[blue red] }, allow_nil: true

  # Scopes
  scope :for_series, ->(series_id) { where(series_id: series_id).order(:game_number) }
end
