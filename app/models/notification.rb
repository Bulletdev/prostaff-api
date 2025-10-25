# frozen_string_literal: true

# Model representing user notifications for system events and updates
#
# This model manages in-app notifications for users, supporting multiple notification
# types (info, success, warning, error, match, schedule, system) and delivery channels.
# Notifications can be marked as read/unread and are tracked with timestamps.
#
# Associated with:
# - User: The user who receives the notification
#
# @example Create a notification
#   notification = Notification.create(
#     user: user,
#     title: 'Match Scheduled',
#     message: 'Your match against Team Alpha is scheduled for tomorrow at 3 PM',
#     type: 'match',
#     channels: ['in_app', 'email']
#   )
#
# @example Query unread notifications
#   user.notifications.unread.recent
#
# @example Mark notification as read
#   notification.mark_as_read!
class Notification < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :title, presence: true, length: { maximum: 200 }
  validates :message, presence: true
  validates :type, presence: true, inclusion: {
    in: %w[info success warning error match schedule system],
    message: '%{value} is not a valid notification type'
  }

  # Scopes
  scope :unread, -> { where(is_read: false) }
  scope :read, -> { where(is_read: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(type: type) }

  # Callbacks
  before_create :set_default_channels

  # Instance methods
  def mark_as_read!
    update!(is_read: true, read_at: Time.current)
  end

  def unread?
    !is_read
  end

  private

  def set_default_channels
    self.channels ||= ['in_app']
  end
end
