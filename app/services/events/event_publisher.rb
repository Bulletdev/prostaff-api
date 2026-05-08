# frozen_string_literal: true

module Events
  # Publishes domain events to prostaff-events (Phoenix) for real-time WebSocket delivery.
  #
  # Design: fire-and-forget via Sidekiq. A Phoenix outage NEVER breaks a Rails request.
  # All failures are logged and swallowed. Uses queue :events (retry: 0 — stale events
  # have no value if delayed > a few seconds).
  #
  # Transport: Rails publishes to Redis pub/sub channel; Phoenix subscribes via
  # Phoenix.PubSub Redis adapter. No HTTP from Rails to Phoenix.
  #
  # @example
  #   Events::EventPublisher.publish(
  #     user_id:         current_user.id,
  #     org_id:          current_organization.id,
  #     type:            'scrim_request.accepted',
  #     payload:         { scrim_request_id: @scrim_request.id }
  #   )
  class EventPublisher
    REDIS_CHANNEL_PREFIX = 'prostaff:events'

    # Publishes a domain event asynchronously. Never raises.
    #
    # @param user_id [String] UUID of the acting user (for audit/routing)
    # @param org_id  [String] Organization UUID (for tenant-scoped broadcasting)
    # @param type    [String] Dot-notation event type, e.g. 'scrim_request.accepted'
    # @param payload [Hash]   Arbitrary event data
    def self.publish(user_id:, org_id:, type:, payload: {})
      unless type.present? && user_id.present? && org_id.present?
        Rails.logger.warn(event: 'event_publisher_skipped', reason: 'missing_fields', type: type)
        return
      end

      Events::EventPublishJob.perform_later(
        user_id: user_id.to_s,
        org_id: org_id.to_s,
        type: type,
        payload: payload
      )
    rescue StandardError => e
      Rails.logger.error(event: 'event_publisher_enqueue_error', type: type, error: e.message)
    end
  end
end
