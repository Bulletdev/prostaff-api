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
  #   - current_user      → the authenticated User record (nil for player tokens)
  #   - current_player    → the authenticated Player record (nil for user tokens)
  #   - current_org_id    → organization_id extracted from the token
  #
  # On failure, calls reject_unauthorized_connection.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_player, :current_org_id

    def connect
      payload = decode_token
      route_by_token_type(payload)
    end

    private

    def decode_token
      token = request.params[:token]
      reject_unauthorized_connection if token.blank?

      payload = JwtService.decode(token)

      if payload[:type] != 'access'
        logger.warn "[ActionCable] Rejected non-access token type: #{payload[:type]}"
        reject_unauthorized_connection
      end

      payload
    rescue JwtService::AuthenticationError => e
      logger.warn "[ActionCable] JWT rejected: #{e.message}"
      reject_unauthorized_connection
    end

    def route_by_token_type(payload)
      if payload[:entity_type] == 'player'
        authenticate_player_connection(payload)
      else
        authenticate_user_connection(payload)
      end
    end

    def authenticate_user_connection(payload)
      user = find_user(payload[:user_id])
      validate_organization!(user.organization_id, label: "User #{user.id}")

      self.current_user   = user
      self.current_player = nil
      self.current_org_id = user.organization_id
      logger.info "[ActionCable] Connected: user=#{user.id} org=#{user.organization_id}"
    end

    def authenticate_player_connection(payload)
      player = find_player(payload[:player_id])
      validate_organization!(player.organization_id, label: "Player #{player.id}")

      self.current_user   = nil
      self.current_player = player
      self.current_org_id = player.organization_id
      logger.info "[ActionCable] Connected: player=#{player.id} org=#{player.organization_id}"
    end

    def find_user(user_id)
      user = User.find_by(id: user_id)
      return user if user

      logger.warn "[ActionCable] User not found for token user_id=#{user_id}"
      reject_unauthorized_connection
    end

    def find_player(player_id)
      player = Player.unscoped.find_by(id: player_id, player_access_enabled: true)
      return player if player

      logger.warn "[ActionCable] Player not found or access disabled: player_id=#{player_id}"
      reject_unauthorized_connection
    end

    def validate_organization!(org_id, label:)
      return if org_id.present?

      logger.warn "[ActionCable] #{label} has no organization — rejected"
      reject_unauthorized_connection
    end
  end
end
