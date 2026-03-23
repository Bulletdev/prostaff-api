# frozen_string_literal: true

# Stores user feedback and feature suggestions submitted via the sidebar drawer.
#
# @attr category [String] Type of feedback: bug, feature, improvement, performance, other
# @attr title    [String] Short summary
# @attr description [String] Full description
# @attr rating   [Integer, nil] Optional 1-5 user satisfaction score
# @attr status   [String] Lifecycle state: open, in_review, resolved, closed
class Feedback < ApplicationRecord
  CATEGORIES = %w[bug feature improvement performance other].freeze
  STATUSES   = %w[open in_review resolved closed].freeze

  belongs_to :user,         optional: true
  belongs_to :organization, optional: true
  has_many   :feedback_votes, dependent: :destroy

  validates :category,    inclusion: { in: CATEGORIES }
  validates :title,       presence: true, length: { maximum: 160 }
  validates :description, presence: true, length: { maximum: 4000 }
  validates :rating,      inclusion: { in: 1..5 }, allow_nil: true
  validates :status,      inclusion: { in: STATUSES }

  scope :open,      -> { where(status: 'open') }
  scope :recent,    -> { order(created_at: :desc) }
  scope :by_category, lambda { |cat| where(category: cat) }
end
