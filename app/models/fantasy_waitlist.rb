class FantasyWaitlist < ApplicationRecord
  # Associations
  belongs_to :organization, optional: true

  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { case_sensitive: false }

  # Callbacks
  before_save :downcase_email
  before_create :set_subscribed_at

  # Scopes
  scope :notified, -> { where(notified: true) }
  scope :not_notified, -> { where(notified: false) }
  scope :recent, -> { order(created_at: :desc) }

  private

  def downcase_email
    self.email = email.downcase.strip if email.present?
  end

  def set_subscribed_at
    self.subscribed_at ||= Time.current
  end
end
