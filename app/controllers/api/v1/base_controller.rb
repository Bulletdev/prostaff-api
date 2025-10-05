class Api::V1::BaseController < ApplicationController
  include Authenticatable
  include Pundit::Authorization

  # Skip authentication for specific actions if needed
  # This will be overridden in individual controllers

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_validation_errors
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden_policy

  protected

  def render_success(data = {}, message: nil, status: :ok)
    response = {}
    response[:message] = message if message
    response[:data] = data if data.present?

    render json: response, status: status
  end

  def render_created(data = {}, message: 'Resource created successfully')
    render_success(data, message: message, status: :created)
  end

  def render_updated(data = {}, message: 'Resource updated successfully')
    render_success(data, message: message, status: :ok)
  end

  def render_deleted(message: 'Resource deleted successfully')
    render json: { message: message }, status: :ok
  end

  def render_error(message:, code: 'ERROR', status: :bad_request, details: nil)
    error_response = {
      error: {
        code: code,
        message: message
      }
    }

    error_response[:error][:details] = details if details

    render json: error_response, status: status
  end

  def render_validation_errors(exception)
    render_error(
      message: 'Validation failed',
      code: 'VALIDATION_ERROR',
      status: :unprocessable_entity,
      details: exception.record.errors.as_json
    )
  end

  def render_not_found(exception = nil)
    resource_name = exception&.model&.humanize || 'Resource'
    render_error(
      message: "#{resource_name} not found",
      code: 'NOT_FOUND',
      status: :not_found
    )
  end

  def render_parameter_missing(exception)
    render_error(
      message: "Missing required parameter: #{exception.param}",
      code: 'PARAMETER_MISSING',
      status: :bad_request
    )
  end

  def paginate(collection, per_page: 20)
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || per_page, 100].min # Max 100 per page

    paginated = collection.page(page).per(per_page)

    {
      data: paginated,
      pagination: {
        current_page: paginated.current_page,
        per_page: paginated.limit_value,
        total_pages: paginated.total_pages,
        total_count: paginated.total_count,
        has_next_page: paginated.next_page.present?,
        has_prev_page: paginated.prev_page.present?
      }
    }
  end

  def log_user_action(action:, entity_type:, entity_id: nil, old_values: {}, new_values: {})
    AuditLog.create!(
      organization: current_organization,
      user: current_user,
      action: action.to_s,
      entity_type: entity_type.to_s,
      entity_id: entity_id,
      old_values: old_values,
      new_values: new_values,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end

  private

  def set_content_type
    response.content_type = 'application/json'
  end

  def render_forbidden_policy(exception)
    policy_name = exception.policy.class.to_s.underscore
    render_error(
      message: "You are not authorized to perform this action",
      code: 'FORBIDDEN',
      status: :forbidden,
      details: {
        policy: policy_name,
        action: exception.query
      }
    )
  end
end