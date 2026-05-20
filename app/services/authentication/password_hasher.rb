# frozen_string_literal: true

module Authentication
  # Handles password hashing and verification with support for lazy migration
  # from bcrypt to Argon2id. The hash format is self-describing, so no extra
  # column or flag is needed to detect which algorithm was used.
  class PasswordHasher
    # Ultra-fast params in test to avoid adding 150-250ms per RSpec example
    # that touches authentication. Production values follow OWASP preferred profile.
    # m_cost is an exponent: memory = 2^m_cost KiB. Valid range: 3..31.
    # m_cost: 16 => 2^16 KiB = 64 MiB (OWASP preferred profile).
    # m_cost: 3  => 2^3  KiB = 8 KiB  (fast for test suite).
    ARGON2_PARAMS = if Rails.env.test?
                      { m_cost: 3, t_cost: 1, p_cost: 1 }.freeze
                    else
                      { m_cost: 16, t_cost: 3, p_cost: 2 }.freeze
                    end

    # Covers $2a$ (standard), $2b$ (canonical), $2x$/$2y$ (legacy JRuby/PHP variants)
    BCRYPT_PREFIX = /\A\$2[abxy]\$/

    def self.hash(plain_password)
      Argon2::Password.create(plain_password, **ARGON2_PARAMS)
    end

    def self.verify(plain_password, digest)
      return false if plain_password.blank? || digest.blank?

      bcrypt?(digest) ? verify_bcrypt(plain_password, digest) : verify_argon2(plain_password, digest)
    end

    def self.needs_upgrade?(digest)
      bcrypt?(digest)
    end

    def self.bcrypt?(digest)
      digest.to_s.match?(BCRYPT_PREFIX)
    end

    def self.verify_bcrypt(plain_password, digest)
      result = BCrypt::Password.new(digest) == plain_password
      Rails.logger.info('[PasswordHasher] bcrypt digest detected — upgrade queued') if result
      result
    rescue BCrypt::Errors::InvalidHash
      false
    end
    private_class_method :verify_bcrypt

    def self.verify_argon2(plain_password, digest)
      Argon2::Password.verify_password(plain_password, digest)
    rescue Argon2::Error
      false
    end
    private_class_method :verify_argon2
  end
end
