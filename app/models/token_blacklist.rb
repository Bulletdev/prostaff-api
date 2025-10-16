# frozen_string_literal: true

class TokenBlacklist < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :valid, -> { where('expires_at > ?', Time.current) }

  def self.blacklisted?(jti)
    valid.exists?(jti: jti)
  end

  def self.add_to_blacklist(jti, expires_at)
    create!(jti: jti, expires_at: expires_at)
  rescue ActiveRecord::RecordInvalid
    nil
  end

  def self.cleanup_expired
    expired.delete_all
  end
end
