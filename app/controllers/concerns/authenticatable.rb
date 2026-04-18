# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    # RLS disabled - Rails handles organization scoping at application level
    # include RowLevelSecurity

    before_action :authenticate_request!
    before_action :set_current_user
    before_action :set_current_organization
  end

  private

  def authenticate_request!
    token = extract_token_from_header

    if token.nil?
      render_unauthorized('Missing authentication token')
      return
    end

    perform_authentication(token)
  end

  def perform_authentication(token)
    @jwt_payload = JwtService.decode(token)

    # Reject refresh tokens used as access tokens.
    # Refresh tokens carry type: 'refresh' and must never authenticate a request.
    raise JwtService::TokenInvalidError, 'Invalid token type' unless valid_access_token_type?(@jwt_payload)

    if @jwt_payload[:entity_type] == 'player'
      authenticate_player_token
    else
      authenticate_user_token
    end
  rescue JwtService::AuthenticationError => e
    Rails.logger.error("JWT Authentication error: #{e.class} - #{e.message}")
    render_unauthorized(e.message)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("User not found during authentication: #{e.message}")
    render_unauthorized('User not found')
  rescue StandardError => e
    Rails.logger.error("Unexpected authentication error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    render json: { error: { code: 'INTERNAL_ERROR', message: 'An internal error occurred' } },
           status: :internal_server_error
  end

  def authenticate_player_token
    # Free agents (auto-cadastro via ArenaBR) têm organization_id: nil
    @current_player = Player.unscoped.find(@jwt_payload[:player_id])
    org_id = @jwt_payload[:organization_id]
    @current_organization = org_id.present? ? Organization.find(org_id) : nil
    Current.organization_id = @current_organization&.id
    org_label = @current_organization&.id || 'free_agent'
    Rails.logger.info("[AUTH] Player token: player_id=#{@current_player.id} org=#{org_label}")
  end

  def authenticate_user_token
    # Bypass RLS for authentication queries - we need to find the user before we can set RLS context
    @current_user = User.unscoped.find(@jwt_payload[:user_id])
    @current_organization = @current_user.organization
    Current.organization_id = @current_organization.id
    Current.user_id = @current_user.id
    Current.user_role = @current_user.role
    Rails.logger.info("[AUTH] Set Current.organization_id=#{Current.organization_id} for user #{@current_user.email}")
    @current_user.update_last_login! if should_update_last_login?
  end

  def extract_token_from_header
    auth_header = request.headers['Authorization']
    return nil unless auth_header

    match = auth_header.match(/Bearer\s+(.+)/i)
    match&.[](1)
  end

  def current_user
    @current_user
  end

  def current_player
    @current_player
  end

  def player_authenticated?
    @current_player.present?
  end

  def current_organization
    @current_organization
  end

  def current_user_id
    @current_user&.id
  end

  def current_organization_id
    @current_organization&.id
  end

  def user_signed_in?
    @current_user.present?
  end

  def require_admin!
    return if current_user&.admin_or_owner?

    render_forbidden('Admin access required')
  end

  def require_owner!
    return if current_user&.role == 'owner'

    render_forbidden('Owner access required')
  end

  def require_role!(*allowed_roles)
    return if allowed_roles.include?(current_user&.role)

    render_forbidden("Required role: #{allowed_roles.join(' or ')}")
  end

  # Rejects player tokens — for endpoints that are staff-only (e.g. chat members)
  def require_user_auth!
    return if user_signed_in?

    render_forbidden('User authentication required — player tokens are not accepted here')
  end

  def organization_scoped(model_class)
    model_class.where(organization: current_organization)
  end

  def set_current_user
    # This method can be overridden in controllers if needed
  end

  def set_current_organization
    # This method can be overridden in controllers if needed
  end

  # Returns true only for tokens that are valid for authenticating API requests.
  #
  # Refresh tokens (type: 'refresh') must be rejected even if they are otherwise
  # well-formed and not expired. Player access tokens carry entity_type: 'player'
  # AND type: 'access'; user access tokens carry type: 'access'.
  #
  # @param payload [HashWithIndifferentAccess] Decoded JWT payload
  # @return [Boolean]
  def valid_access_token_type?(payload)
    payload[:type] == 'access'
  end

  def should_update_last_login?
    return false unless @current_user
    return true if @current_user.last_login_at.nil?

    # Only update if last login was more than 1 hour ago to avoid too many updates
    @current_user.last_login_at < 1.hour.ago
  end

  def render_unauthorized(message = 'Unauthorized')
    render json: {
      error: {
        code: 'UNAUTHORIZED',
        message: message
      }
    }, status: :unauthorized
  end

  def render_forbidden(message = 'Forbidden')
    render json: {
      error: {
        code: 'FORBIDDEN',
        message: message
      }
    }, status: :forbidden
  end
end
