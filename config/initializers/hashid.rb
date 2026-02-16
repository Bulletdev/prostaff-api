# frozen_string_literal: true

# HashID Configuration for URL Obfuscation
#
# This initializer configures Hashid::Rails for generating short, obfuscated URLs
# for public-facing resources like VOD Reviews, Draft Plans, and Tactical Boards.
#
# @see https://github.com/jcypret/hashid-rails

require 'hashid/rails'

Hashid::Rails.configure do |config|
  # Salt: MUST be set via ENV for security
  salt = ENV.fetch('HASHID_SALT') do
    if Rails.env.production?
      raise 'HASHID_SALT environment variable must be set in production!'
    else
      Rails.logger.warn '[HASHID] Using fallback salt in development. Set HASHID_SALT for production!'
      'development_fallback_salt'
    end
  end
  config.salt = salt

  # Minimum length of HashIDs
  # Lower = shorter URLs (e.g., 6 = "aBcD3f")
  # Higher = more obfuscation (e.g., 12 = "aBcD3fGhIjKl")
  min_length = ENV.fetch('HASHID_MIN_LENGTH') do
    if Rails.env.production?
      Rails.logger.warn '[HASHID] HASHID_MIN_LENGTH not set, using default: 6'
      '6'
    else
      '6'
    end
  end
  config.min_hash_length = min_length.to_i

  # Alphabet: Use Base62 by default (a-z, A-Z, 0-9)
  config.alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
end

Rails.application.config.after_initialize do
  min_length = ENV.fetch('HASHID_MIN_LENGTH', '6')
  salt = ENV.fetch('HASHID_SALT', 'development_fallback_salt')

  Rails.logger.info '[HASHID] Initialized with:'
  Rails.logger.info "  - Salt: #{salt[0..2]}*** (hidden)"
  Rails.logger.info "  - Min Length: #{min_length}"
  Rails.logger.info "  - Alphabet: Base62 (a-z, A-Z, 0-9)"
end
