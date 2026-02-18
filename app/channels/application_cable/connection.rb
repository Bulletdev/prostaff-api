# frozen_string_literal: true

module ApplicationCable
  # WebSocket connection handler.
  #
  # Authenticates the connection using the JWT token passed as a query param.
  # The token is decoded via the same JwtService used by the REST API,
  # which also checks the blacklist — revoked tokens cannot open connections.
  #
  # Connection URL expected from frontend:
  #   wss://api.prostaff.gg/cable?token=<JWT_ACCESS_TOKEN>
  #
  # On success, sets:
  #   - current_user      → the authenticated User record
  #   - current_org_id    → organization_id extracted from the user
  #
  # On failure, calls reject_unauthorized_connection.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_org_id

    def connect
      self.current_user   = find_verified_user
      self.current_org_id = current_user.organization_id
    end

    private

    def find_verified_user
      token = request.params[:token]

      reject_unauthorized_connection if token.blank?

      payload = Authentication::Services::JwtService.decode(token)

      # Only accept access tokens — reject refresh tokens
      if payload[:type] != 'access'
        logger.warn "[ActionCable] Rejected non-access token type: #{payload[:type]}"
        reject_unauthorized_connection
      end

      user = User.find_by(id: payload[:user_id])

      if user.nil?
        logger.warn "[ActionCable] User not found for token user_id=#{payload[:user_id]}"
        reject_unauthorized_connection
      end

      unless user.organization_id.present?
        logger.warn "[ActionCable] User #{user.id} has no organization — rejected"
        reject_unauthorized_connection
      end

      logger.info "[ActionCable] Connected: user=#{user.id} org=#{user.organization_id}"
      user
    rescue Authentication::Services::JwtService::AuthenticationError => e
      logger.warn "[ActionCable] JWT rejected: #{e.message}"
      reject_unauthorized_connection
    end
  end
end
