# frozen_string_literal: true

class PasswordResetToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :valid, -> { where('expires_at > ? AND used_at IS NULL', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :used, -> { where.not(used_at: nil) }

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  def mark_as_used!
    update!(used_at: Time.current)
  end

  def valid_token?
    expires_at > Time.current && used_at.nil?
  end

  def expired?
    expires_at <= Time.current
  end

  def used?
    used_at.present?
  end

  def self.generate_secure_token
    SecureRandom.urlsafe_base64(32)
  end

  def self.cleanup_old_tokens
    where('expires_at < ? OR used_at < ?', 24.hours.ago, 24.hours.ago).delete_all
  end

  private

  def generate_token
    self.token ||= self.class.generate_secure_token
  end

  def set_expiration
    self.expires_at ||= 1.hour.from_now
  end
end
