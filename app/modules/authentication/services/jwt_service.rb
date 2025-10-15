module Authentication
  module Services
    class JwtService
      SECRET_KEY = ENV.fetch('JWT_SECRET_KEY') { Rails.application.secret_key_base }
      EXPIRATION_HOURS = ENV.fetch('JWT_EXPIRATION_HOURS', 24).to_i

      class << self
        def encode(payload)
          payload[:jti] ||= SecureRandom.uuid
          payload[:exp] = EXPIRATION_HOURS.hours.from_now.to_i
          payload[:iat] = Time.current.to_i

          JWT.encode(payload, SECRET_KEY, 'HS256')
        end

        def decode(token)
          decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
          payload = HashWithIndifferentAccess.new(decoded[0])

          if payload[:jti].present? && TokenBlacklist.blacklisted?(payload[:jti])
            raise AuthenticationError, 'Token has been revoked'
          end

          payload
        rescue JWT::DecodeError => e
          raise AuthenticationError, "Invalid token: #{e.message}"
        rescue JWT::ExpiredSignature
          raise AuthenticationError, 'Token has expired'
        end

        def generate_tokens(user)
          access_jti = SecureRandom.uuid
          refresh_jti = SecureRandom.uuid

          access_payload = {
            jti: access_jti,
            user_id: user.id,
            organization_id: user.organization_id,
            role: user.role,
            email: user.email,
            type: 'access'
          }

          refresh_payload = {
            jti: refresh_jti,
            user_id: user.id,
            organization_id: user.organization_id,
            type: 'refresh',
            exp: 7.days.from_now.to_i,
            iat: Time.current.to_i
          }

          {
            access_token: encode(access_payload),
            refresh_token: JWT.encode(refresh_payload, SECRET_KEY, 'HS256'),
            expires_in: EXPIRATION_HOURS.hours.to_i,
            token_type: 'Bearer'
          }
        end

        def refresh_access_token(refresh_token)
          decoded = JWT.decode(refresh_token, SECRET_KEY, true, { algorithm: 'HS256' })
          payload = HashWithIndifferentAccess.new(decoded[0])

          raise AuthenticationError, 'Invalid refresh token' unless payload[:type] == 'refresh'

          if payload[:jti].present? && TokenBlacklist.blacklisted?(payload[:jti])
            raise AuthenticationError, 'Refresh token has been revoked'
          end

          user = User.find(payload[:user_id])

          blacklist_token(refresh_token)

          generate_tokens(user)
        rescue JWT::DecodeError => e
          raise AuthenticationError, "Invalid refresh token: #{e.message}"
        rescue JWT::ExpiredSignature
          raise AuthenticationError, 'Refresh token has expired'
        rescue ActiveRecord::RecordNotFound
          raise AuthenticationError, 'User not found'
        end

        def extract_user_from_token(token)
          payload = decode(token)
          User.find(payload[:user_id])
        rescue ActiveRecord::RecordNotFound
          raise AuthenticationError, 'User not found'
        end

        def blacklist_token(token)
          decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
          payload = HashWithIndifferentAccess.new(decoded[0])

          return unless payload[:jti].present?

          expires_at = Time.at(payload[:exp]) if payload[:exp]
          expires_at ||= EXPIRATION_HOURS.hours.from_now

          TokenBlacklist.add_to_blacklist(payload[:jti], expires_at)
        rescue JWT::DecodeError, JWT::ExpiredSignature
          nil
        end
      end

      class AuthenticationError < StandardError; end
    end
  end
end