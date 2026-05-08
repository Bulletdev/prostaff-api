# frozen_string_literal: true

# Represents an internal practice session where an organization's own players
# compete against each other in a controlled environment.
#
# An inhouse goes through four phases:
#   waiting     — lobby open, players joining
#   draft       — captain draft in progress (picks 1-2-2-2-1)
#   in_progress — teams set, games being played
#   done        — session closed
#
class Inhouse < ApplicationRecord
  PICK_ORDER = %w[blue red red blue blue red red blue].freeze

  # Associations
  belongs_to :organization
  belongs_to :created_by, class_name: 'User', foreign_key: :created_by_user_id
  belongs_to :blue_captain, class_name: 'Player', optional: true
  belongs_to :red_captain,  class_name: 'Player', optional: true
  has_many :inhouse_participations, dependent: :destroy
  has_many :players, through: :inhouse_participations

  # Enum
  enum :status, { waiting: 'waiting', draft: 'draft', in_progress: 'in_progress', done: 'done' }, prefix: false

  # Scopes
  scope :active, -> { where(status: %w[waiting draft in_progress]) }
  scope :history, -> { where(status: 'done') }
  scope :recent, -> { order(created_at: :desc) }

  # Validations
  validates :status, presence: true, inclusion: { in: statuses.keys }

  validate :valid_status_transition, on: :update

  # Returns which team should pick next during draft ('blue' or 'red').
  # Returns nil if draft is not active or all picks are done.
  def current_pick_team
    return nil unless draft?
    return nil if draft_pick_number.nil?
    return nil if draft_pick_number >= PICK_ORDER.size

    PICK_ORDER[draft_pick_number]
  end

  # True when all 8 non-captain picks have been made.
  def draft_complete?
    draft_pick_number.to_i >= PICK_ORDER.size
  end

  private

  def valid_status_transition
    return unless status_changed?

    allowed = {
      'waiting' => %w[draft in_progress done],
      'draft' => %w[in_progress done],
      'in_progress' => %w[done],
      'done' => []
    }

    previous = status_was
    return if allowed.fetch(previous, []).include?(status)

    errors.add(:status, "cannot transition from '#{previous}' to '#{status}'")
  end
end
