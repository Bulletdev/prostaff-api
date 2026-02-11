# frozen_string_literal: true

class HealthController < ActionController::API
  # Skip authentication and authorization for health checks
  skip_before_action :verify_authenticity_token, raise: false

  # Simple health check that doesn't check database
  def index
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      service: 'ProStaff API'
    }, status: :ok
  end

  # Detailed health check with database verification
  def show
    database_status = check_database

    render json: {
      status: database_status ? 'ok' : 'degraded',
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      service: 'ProStaff API',
      database: database_status ? 'connected' : 'disconnected'
    }, status: database_status ? :ok : :service_unavailable
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue StandardError => e
    Rails.logger.error "Health check database error: #{e.message}"
    false
  end
end
