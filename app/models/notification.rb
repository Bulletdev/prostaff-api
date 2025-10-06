class Notification < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :title, presence: true, length: { maximum: 200 }
  validates :message, presence: true
  validates :type, presence: true, inclusion: {
    in: %w[info success warning error match schedule system],
    message: "%{value} is not a valid notification type"
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
