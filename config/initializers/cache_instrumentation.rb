# frozen_string_literal: true

# Subscribes to Rails cache read events and increments Redis counters so that
# cache hit rate can be observed without an external APM agent.
#
# Counters stored in Redis:
#   metrics:cache:reads   — total cache reads
#   metrics:cache:hits    — reads that returned a cached value
#   metrics:cache:misses  — reads that missed the cache
#
# These counters are intentionally never reset automatically so that they
# accumulate across deployments.  Reset manually via Rails console:
#   Rails.cache.redis.call('DEL', 'metrics:cache:reads', 'metrics:cache:hits', 'metrics:cache:misses')
#
# Exposed via GET /api/v1/monitoring/cache_stats (admin only).
ActiveSupport::Notifications.subscribe('cache_read.active_support') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  hit   = event.payload[:hit]

  Rails.cache.redis.pipelined do |pipe|
    pipe.call('INCR', 'metrics:cache:reads')
    pipe.call('INCR', hit ? 'metrics:cache:hits' : 'metrics:cache:misses')
  end
rescue StandardError
  # Instrumentation must never raise — a Redis failure here must not break the request.
end
