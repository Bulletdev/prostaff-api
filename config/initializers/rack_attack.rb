class Rack::Attack
  # Enable caching for Rack::Attack using Rails cache store
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Allow localhost in development
  safelist('allow from localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip if Rails.env.development?
  end

  # Throttle all requests by IP
  throttle('req/ip', limit: ENV.fetch('RACK_ATTACK_LIMIT', 300).to_i, period: ENV.fetch('RACK_ATTACK_PERIOD', 300).to_i) do |req|
    req.ip
  end

  # Throttle login attempts
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/auth/login' && req.post?
      req.ip
    end
  end

  # Throttle registration
  throttle('register/ip', limit: 3, period: 1.hour) do |req|
    if req.path == '/api/v1/auth/register' && req.post?
      req.ip
    end
  end

  # Throttle password reset requests
  throttle('password_reset/ip', limit: 5, period: 1.hour) do |req|
    if req.path == '/api/v1/auth/forgot-password' && req.post?
      req.ip
    end
  end

  # Throttle API requests per authenticated user
  throttle('req/authenticated_user', limit: 1000, period: 1.hour) do |req|
    if req.env['rack.jwt.payload']
      req.env['rack.jwt.payload']['user_id']
    end
  end

  # Log blocked requests
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    Rails.logger.warn "[Rack::Attack] Blocked #{req.env['REQUEST_METHOD']} #{req.url} from #{req.ip} at #{Time.current}"
  end
end