# frozen_string_literal: true

# Public status page endpoint returning component health in Statuspage-compatible JSON.
# No authentication required — this endpoint is consumed by status.prostaff.gg.
class StatusController < ActionController::API
  skip_before_action :verify_authenticity_token, raise: false

  COMPONENT_META = {
    'api'       => { name: 'API',                        description: 'Core REST API services' },
    'database'  => { name: 'Database',                   description: 'PostgreSQL primary database' },
    'redis'     => { name: 'Cache & Background Jobs',    description: 'Redis cache and Sidekiq queue processor' },
    'websocket' => { name: 'Real-time (WebSocket)',       description: 'ActionCable WebSocket connections' },
    'sidekiq'   => { name: 'Background Jobs (Sidekiq)',  description: 'Async job processing' },
    'riot_api'  => { name: 'Riot API Integration',       description: 'Riot Games data synchronization' }
  }.freeze

  def index
    cached = Rails.cache.fetch('status_page/v2', expires_in: 30.seconds) do
      components = build_component_statuses
      incidents  = build_incidents
      uptime     = build_uptime_history
      indicator, description = overall_status(components)

      {
        status:         { indicator: indicator, description: description },
        components:     components,
        incidents:      incidents,
        uptime_history: uptime
      }
    end

    render json: cached.merge(
      page: {
        id:         'prostaff',
        name:       'ProStaff',
        url:        'https://status.prostaff.gg',
        time_zone:  'UTC',
        updated_at: Time.current.iso8601
      }
    ), status: :ok
  end

  private

  def build_component_statuses
    latest = StatusSnapshot.latest_per_component

    StatusIncident::COMPONENTS.map do |component|
      if (snapshot = latest[component])
        build_component_from_snapshot(component, snapshot)
      else
        build_component_live(component)
      end
    end
  end

  def build_component_from_snapshot(component, snapshot)
    meta = COMPONENT_META[component]
    {
      id:               component,
      name:             meta[:name],
      status:           snapshot.status,
      description:      meta[:description],
      response_time_ms: snapshot.response_time_ms,
      last_checked_at:  snapshot.checked_at.iso8601,
      updated_at:       snapshot.updated_at.iso8601
    }
  end

  def build_component_live(component)
    meta   = COMPONENT_META[component]
    result = live_check(component)

    {
      id:               component,
      name:             meta[:name],
      status:           result[:status],
      description:      meta[:description],
      response_time_ms: result[:response_time_ms],
      last_checked_at:  Time.current.iso8601,
      updated_at:       Time.current.iso8601
    }
  end

  def live_check(component)
    case component
    when 'api'      then live_check_api
    when 'database' then live_check_database
    when 'redis'    then live_check_redis
    else                 { status: 'operational', response_time_ms: nil }
    end
  end

  def live_check_api
    { status: 'operational', response_time_ms: nil }
  end

  def live_check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'operational', response_time_ms: nil }
  rescue StandardError => e
    Rails.logger.error("[STATUS] Live DB check error: #{e.message}")
    { status: 'major_outage', response_time_ms: nil }
  end

  def live_check_redis
    Sidekiq.redis(&:ping)
    { status: 'operational', response_time_ms: nil }
  rescue StandardError => e
    Rails.logger.error("[STATUS] Live Redis check error: #{e.message}")
    { status: 'major_outage', response_time_ms: nil }
  end

  def build_incidents
    StatusIncident.active.recent.includes(:updates).limit(10).map do |incident|
      serialize_incident(incident)
    end
  rescue StandardError => e
    Rails.logger.error("[STATUS] Failed to load incidents: #{e.message}")
    []
  end

  def serialize_incident(incident)
    {
      id:                  incident.id,
      title:               incident.title,
      body:                incident.body,
      severity:            incident.severity,
      status:              incident.status,
      affected_components: incident.affected_components,
      started_at:          incident.started_at.iso8601,
      resolved_at:         incident.resolved_at&.iso8601,
      postmortem:          incident.postmortem,
      updates:             incident.updates.order(created_at: :desc).map do |u|
        { id: u.id, status: u.status, body: u.body, created_at: u.created_at.iso8601 }
      end
    }
  end

  def build_uptime_history
    bulk = StatusSnapshot.bulk_uptime_by_day(days: 90)
    StatusIncident::COMPONENTS.each_with_object({}) do |component, hash|
      hash[component] = bulk[component] || []
    end
  rescue StandardError => e
    Rails.logger.error("[STATUS] Failed to build uptime history: #{e.message}")
    {}
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
