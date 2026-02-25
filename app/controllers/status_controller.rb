# frozen_string_literal: true

# Public status page endpoint returning component health in Statuspage-compatible JSON.
class StatusController < ActionController::API
  skip_before_action :verify_authenticity_token, raise: false

  def index
    components = build_component_statuses
    overall_indicator, overall_description = overall_status(components)

    render json: {
      page: {
        id: 'prostaff',
        name: 'ProStaff',
        url: 'https://status.prostaff.gg',
        time_zone: 'UTC',
        updated_at: Time.current.iso8601
      },
      status: {
        indicator: overall_indicator,
        description: overall_description
      },
      components: components,
      incidents: []
    }, status: :ok
  end

  private

  def build_component_statuses
    [
      api_component,
      database_component,
      redis_component,
      websocket_component,
      riot_api_component
    ]
  end

  def api_component
    {
      id: 'api',
      name: 'API',
      status: 'operational',
      description: 'Core REST API services',
      updated_at: Time.current.iso8601
    }
  end

  def database_component
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      status = 'operational'
    rescue StandardError => e
      Rails.logger.error "Status check DB error: #{e.message}"
      status = 'major_outage'
    end

    {
      id: 'database',
      name: 'Database',
      status: status,
      description: 'PostgreSQL primary database',
      updated_at: Time.current.iso8601
    }
  end

  def redis_component
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      redis.ping
      status = 'operational'
    rescue StandardError => e
      Rails.logger.error "Status check Redis error: #{e.message}"
      status = 'major_outage'
    end

    {
      id: 'redis',
      name: 'Cache & Background Jobs',
      status: status,
      description: 'Redis cache and Sidekiq queue processor',
      updated_at: Time.current.iso8601
    }
  end

  def websocket_component
    {
      id: 'websocket',
      name: 'Real-time (WebSocket)',
      status: 'operational',
      description: 'ActionCable WebSocket connections',
      updated_at: Time.current.iso8601
    }
  end

  def riot_api_component
    {
      id: 'riot_api',
      name: 'Riot API Integration',
      status: 'operational',
      description: 'Riot Games data synchronization',
      updated_at: Time.current.iso8601
    }
  end

  def overall_status(components)
    statuses = components.map { |c| c[:status] }

    if statuses.any? { |s| s == 'major_outage' }
      ['major', 'Major System Outage']
    elsif statuses.any? { |s| s == 'partial_outage' }
      ['critical', 'Partial System Outage']
    elsif statuses.any? { |s| s == 'degraded_performance' }
      ['minor', 'Partially Degraded Service']
    else
      ['none', 'All Systems Operational']
    end
  end
end
