# frozen_string_literal: true

# Manages blacklisted JWT tokens for secure logout
#
# When users log out, their JWT token's unique identifier (jti) is added
# to this blacklist to prevent token reuse until expiration.
#
# @attr [String] jti JWT unique identifier
# @attr [DateTime] expires_at Token expiration timestamp
class TokenBlacklist < ApplicationRecord
  REDIS_ROTATION_PREFIX = 'jwt_rotation:'
  REDIS_ROTATION_TTL    = 300 # 5 minutes — covers the rotation window

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

  # Atomically claims a refresh token jti for rotation using Rails.cache write with
  # unless_exist: true (maps to Redis SET NX EX under the redis_cache_store adapter).
  #
  # Returns true if this caller is the first to claim the jti (safe to rotate).
  # Returns false if the jti was already claimed (concurrent replay — reject).
  #
  # The key expires after REDIS_ROTATION_TTL seconds. This window covers the gap
  # between the first JWT decode and the database blacklist insert in refresh_access_token.
  # The database uniqueness constraint on jti is the durable last line of defense
  # once the Redis key expires.
  #
  # Falls back to true (fail open) if Redis is completely unavailable, relying on
  # the database uniqueness constraint to absorb the race window.
  #
  # @param jti [String] The JWT unique identifier from the refresh token payload
  # @return [Boolean] true if claimed successfully, false if already claimed
  def self.claim_for_rotation(jti)
    key = "#{REDIS_ROTATION_PREFIX}#{jti}"
    Rails.cache.write(key, '1', expires_in: REDIS_ROTATION_TTL, unless_exist: true)
  rescue StandardError => e
    Rails.logger.error("[AUTH] Cache unavailable for rotation claim (jti=#{jti}): #{e.message}")
    # Fail open — database uniqueness constraint is the last line of defense
    true
  end

  def self.cleanup_expired
    expired.delete_all
  end
end
