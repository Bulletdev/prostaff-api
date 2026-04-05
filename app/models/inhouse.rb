# frozen_string_literal: true

# Represents an internal practice session where an organization's own players
# compete against each other in a controlled environment.
#
# An inhouse goes through three phases:
#   waiting     — lobby open, players joining
#   in_progress — teams balanced, games being played
#   done        — session closed
#
class Inhouse < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :created_by, class_name: 'User', foreign_key: :created_by_user_id
  has_many :inhouse_participations, dependent: :destroy
  has_many :players, through: :inhouse_participations

  # Enum
  enum :status, { waiting: 'waiting', in_progress: 'in_progress', done: 'done' }, prefix: false

  # Scopes
  scope :active, -> { where(status: %w[waiting in_progress]) }
  scope :history, -> { where(status: 'done') }
  scope :recent, -> { order(created_at: :desc) }

  # Validations
  validates :status, presence: true, inclusion: { in: statuses.keys }

  validate :valid_status_transition, on: :update

  private

  def valid_status_transition
    return unless status_changed?

    allowed = {
      'waiting' => %w[in_progress done],
      'in_progress' => %w[done],
      'done' => []
    }

    previous = status_was
    return if allowed.fetch(previous, []).include?(status)

    errors.add(:status, "cannot transition from '#{previous}' to '#{status}'")
  end
end
