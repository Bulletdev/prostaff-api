# frozen_string_literal: true

module Events
  # Publishes a domain event to Redis pub/sub for Phoenix to consume.
  #
  # Phoenix subscribes to the same Redis instance via Phoenix.PubSub Redis adapter.
  # No HTTP between Rails and Phoenix — Redis is the transport.
  #
  # Queue: :events (dedicated, low priority, retry: 0)
  # Stale events have no user value — better to drop than deliver 30s late.
  class EventPublishJob < ApplicationJob
    queue_as :events
    sidekiq_options retry: 0

    def perform(user_id:, org_id:, type:, payload: {})
      envelope = build_envelope(user_id: user_id, org_id: org_id, type: type, payload: payload)
      channel  = "#{Events::EventPublisher::REDIS_CHANNEL_PREFIX}:#{org_id}"

      Sidekiq.redis do |redis|
        redis.call('PUBLISH', channel, JSON.generate(envelope))
      end

      Rails.logger.info(event: 'event_published', type: type, org_id: org_id)
    rescue StandardError => e
      Rails.logger.error(event: 'event_publish_error', type: type, org_id: org_id, error: e.message)
    end

    private

    def build_envelope(user_id:, org_id:, type:, payload:)
      {
        id: SecureRandom.uuid,
        type: type,
        user_id: user_id,
        org_id: org_id,
        payload: payload,
        published_at: Time.current.iso8601
      }
    end
  end
end
