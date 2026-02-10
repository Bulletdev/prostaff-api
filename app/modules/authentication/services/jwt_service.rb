# frozen_string_literal: true

module Authentication
  module Services
    # JWT Service
    # Handles JSON Web Token generation and validation
    #
    # Dependencies:
    # - Requires TokenBlacklist model with methods: blacklisted?(jti), add_to_blacklist(jti, expires_at)
    # - Requires User model with attributes: id, organization_id, role, email
    class JwtService
      SECRET_KEY = ENV.fetch('JWT_SECRET_KEY') { Rails.application.secret_key_base }
      EXPIRATION_HOURS = ENV.fetch('JWT_EXPIRATION_HOURS', 24).to_i
      REFRESH_EXPIRATION_DAYS = ENV.fetch('JWT_REFRESH_EXPIRATION_DAYS', 7).to_i

      # Custom error classes for granular error handling
      class AuthenticationError < StandardError; end
      class TokenExpiredError < AuthenticationError; end
      class TokenRevokedError < AuthenticationError; end
      class TokenInvalidError < AuthenticationError; end
      class UserNotFoundError < AuthenticationError; end

      class << self
        # Encodes a payload into a JWT token
        # @param payload [Hash] The payload to encode
        # @param custom_expiration [Integer] Optional custom expiration time in seconds from now
        # @return [String] The encoded JWT token
        def encode(payload, custom_expiration: nil)
          payload[:jti] ||= SecureRandom.uuid
          payload[:exp] = custom_expiration || EXPIRATION_HOURS.hours.from_now.to_i
          payload[:iat] = Time.current.to_i

          JWT.encode(payload, SECRET_KEY, 'HS256')
        end

        # Decodes and validates a JWT token
        # @param token [String] The JWT token to decode
        # @return [HashWithIndifferentAccess] The decoded payload
        # @raise [TokenInvalidError, TokenExpiredError, TokenRevokedError]
        def decode(token)
          decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
          payload = HashWithIndifferentAccess.new(decoded[0])

          if payload[:jti].present? && TokenBlacklist.blacklisted?(payload[:jti])
            raise TokenRevokedError, 'Token has been revoked'
          end

          payload
        rescue JWT::ExpiredSignature
          raise TokenExpiredError, 'Token has expired'
        rescue JWT::DecodeError => e
          raise TokenInvalidError, "Invalid token: #{e.message}"
        end

        # Generates both access and refresh tokens for a user
        # @param user [User] The user to generate tokens for
        # @return [Hash] Contains access_token, refresh_token, expires_in, and token_type
        def generate_tokens(user)
          access_payload = {
            user_id: user.id,
            organization_id: user.organization_id,
            role: user.role,
            email: user.email,
            type: 'access'
          }

          refresh_payload = {
            user_id: user.id,
            organization_id: user.organization_id,
            type: 'refresh'
          }

          {
            access_token: encode(access_payload),
            refresh_token: encode(refresh_payload, custom_expiration: REFRESH_EXPIRATION_DAYS.days.from_now.to_i),
            expires_in: EXPIRATION_HOURS.hours.to_i,
            token_type: 'Bearer'
          }
        end

        # Refreshes the access token using a valid refresh token
        # @param refresh_token [String] The refresh token
        # @return [Hash] New access and refresh tokens
        # @raise [TokenInvalidError, TokenExpiredError, TokenRevokedError, UserNotFoundError]
        def refresh_access_token(refresh_token)
          # Use decode() to leverage centralized validation logic
          payload = decode(refresh_token)

          raise TokenInvalidError, 'Invalid refresh token' unless payload[:type] == 'refresh'

          user = User.find(payload[:user_id])

          # Blacklist the old refresh token (passing payload to avoid re-decoding)
          blacklist_token(refresh_token, payload: payload)

          generate_tokens(user)
        rescue ActiveRecord::RecordNotFound
          raise UserNotFoundError, 'User not found'
        end

        # Extracts and returns the user from a valid token
        # @param token [String] The JWT token
        # @return [User] The user associated with the token
        # @raise [UserNotFoundError]
        def extract_user_from_token(token)
          payload = decode(token)
          User.find(payload[:user_id])
        rescue ActiveRecord::RecordNotFound
          raise UserNotFoundError, 'User not found'
        end

        # Adds a token to the blacklist
        # @param token [String] The JWT token to blacklist
        # @param payload [Hash] Optional pre-decoded payload to avoid re-decoding
        # @return [void]
        def blacklist_token(token, payload: nil)
          # Use provided payload or decode the token
          unless payload
            decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
            payload = HashWithIndifferentAccess.new(decoded[0])
          end

          return unless payload[:jti].present?

          expires_at = Time.at(payload[:exp]) if payload[:exp]
          expires_at ||= EXPIRATION_HOURS.hours.from_now

          TokenBlacklist.add_to_blacklist(payload[:jti], expires_at)
        rescue JWT::DecodeError, JWT::ExpiredSignature => e
          # Log for debugging, but silently fail to not break the flow
          Rails.logger.warn("Failed to blacklist token: #{e.message}")
          nil
        end
      end
    end
  end
end
