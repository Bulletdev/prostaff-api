# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    # RLS disabled - Rails handles organization scoping at application level
    # include RowLevelSecurity

    before_action :authenticate_request!
    before_action :set_current_user
    before_action :set_current_organization
    around_action :set_organization_context
  end

  private

  def authenticate_request!
    token = extract_token_from_header

    if token.nil?
      render_unauthorized('Missing authentication token')
      return
    end

    begin
      @jwt_payload = Authentication::Services::JwtService.decode(token)

      # Bypass RLS for authentication queries - we need to find the user before we can set RLS context
      @current_user = User.unscoped.find(@jwt_payload[:user_id])
      @current_organization = @current_user.organization

      # Set thread-local variables BEFORE update_last_login! to ensure AuditLog creation works
      Thread.current[:current_organization_id] = @current_organization.id
      Thread.current[:current_user_id] = @current_user.id
      Thread.current[:current_user_role] = @current_user.role

      # Update last login time (skip audit log for this update)
      @current_user.update_column(:last_login_at, Time.current) if should_update_last_login?
    rescue Authentication::Services::JwtService::AuthenticationError => e
      Rails.logger.error("JWT Authentication error: #{e.class} - #{e.message}")
      render_unauthorized(e.message)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error("User not found during authentication: #{e.message}")
      render_unauthorized('User not found')
    rescue StandardError => e
      Rails.logger.error("Unexpected authentication error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: {
        error: {
          code: 'INTERNAL_ERROR',
          message: 'An internal error occurred'
        }
      }, status: :internal_server_error
    end
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

  def organization_scoped(model_class)
    model_class.where(organization: current_organization)
  end

  def set_current_user
    # This method can be overridden in controllers if needed
  end

  def set_current_organization
    # This method can be overridden in controllers if needed
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

  def set_organization_context
    # Set thread-local variables for OrganizationScoped concern
    if current_organization && current_user
      Thread.current[:current_organization_id] = current_organization.id
      Thread.current[:current_user_id] = current_user.id
      Thread.current[:current_user_role] = current_user.role
    end

    yield
  ensure
    # Always reset thread-local variables
    Thread.current[:current_organization_id] = nil
    Thread.current[:current_user_id] = nil
    Thread.current[:current_user_role] = nil
  end
end
