module Authenticatable
  extend ActiveSupport::Concern

  included do
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

    begin
      @jwt_payload = Authentication::Services::JwtService.decode(token)
      @current_user = User.find(@jwt_payload[:user_id])
      @current_organization = @current_user.organization

      # Update last login time
      @current_user.update_last_login! if should_update_last_login?

    rescue Authentication::Services::JwtService::AuthenticationError => e
      render_unauthorized(e.message)
    rescue ActiveRecord::RecordNotFound
      render_unauthorized('User not found')
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
    unless current_user&.admin_or_owner?
      render_forbidden('Admin access required')
    end
  end

  def require_owner!
    unless current_user&.role == 'owner'
      render_forbidden('Owner access required')
    end
  end

  def require_role!(*allowed_roles)
    unless allowed_roles.include?(current_user&.role)
      render_forbidden("Required role: #{allowed_roles.join(' or ')}")
    end
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
end