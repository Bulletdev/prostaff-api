# frozen_string_literal: true

module Rack
  class Attack
    # Enable caching for Rack::Attack
    # Development: MemoryStore (simples e rápido)
    # Production: Redis DB 0 (persistente, compartilhado entre replicas)
    # Falls back to MemoryStore if Redis is unavailable
    Rack::Attack.cache.store = if Rails.env.production? && ENV['REDIS_URL'].present?
                                 begin
                                   ActiveSupport::Cache::RedisCacheStore.new(
                                     url: ENV['REDIS_URL'],
                                     reconnect_attempts: 3,
                                     error_handler: lambda { |_method:, _returning:, exception:|
                                       Rails.logger.warn "Rack::Attack Redis error: #{exception.message}"
                                     },
                                     namespace: 'rack_attack'
                                   )
                                 rescue StandardError => e
                                   Rails.logger.warn "Failed to connect to Redis for Rack::Attack, falling back to MemoryStore: #{e.message}"
                                   ActiveSupport::Cache::MemoryStore.new
                                 end
                               else
                                 ActiveSupport::Cache::MemoryStore.new
                               end

    # Allow health check endpoints (Docker healthchecks, monitoring, load balancers)
    HEALTH_PATHS = %w[/health /health/live /health/ready /health/detailed /up /api/health].freeze

    safelist('allow health checks') do |req|
      HEALTH_PATHS.any? { |p| req.path == p }
    end

    # Allow SEO-friendly endpoints (sitemap, robots.txt)
    safelist('allow seo endpoints') do |req|
      ['/sitemap.xml', '/robots.txt'].include?(req.path)
    end

    # Allow localhost and Docker bridge in development and test environments
    safelist('allow from localhost') do |req|
      next false unless Rails.env.development? || Rails.env.test?

      ip = req.ip.to_s
      ip == '127.0.0.1' || ip == '::1' || ip.start_with?('172.18.', '172.17.')
    end

    # Block known malicious bots and scrapers
    MALICIOUS_BOTS = [
      'AhrefsBot', 'SemrushBot', 'MJ12bot', 'DotBot', 'rogerBot', 'SiteExplorer', 'OpenLinkProfiler', 'SEOkicks', 'Lipperhey', 'Exabot', 'BLEXBot', 'MegaIndex.ru', 'Cliqzbot', 'PetalBot', 'AspiegelBot', 'ZoominfoBot', 'DataForSeoBot', 'Bytespider', 'GPTBot', 'ChatGPT-User', 'CCBot', 'anthropic-ai', 'Claude-Web', 'cohere-ai', 'PerplexityBot', 'EmailCollector', 'EmailSiphon', 'EmailWolf', 'HTTrack', 'WebCopier', 'Teleport', 'TeleportPro', 'WebReaper', 'WebStripper', 'WebZip', 'BackDoorBot', 'Screaming Frog SEO Spider'
    ].freeze

    blocklist('block malicious bots') do |req|
      user_agent = req.user_agent.to_s.downcase
      MALICIOUS_BOTS.any? { |bot| user_agent.include?(bot.downcase) }
    end

    # Block suspicious requests (no user agent)
    # Allow OPTIONS requests (CORS preflight) and health probes even without user agent
    blocklist('block requests without user agent') do |req|
      req.user_agent.blank? &&
        HEALTH_PATHS.none? { |p| req.path == p } &&
        req.request_method != 'OPTIONS'
    end

    # Block requests with suspicious patterns
    blocklist('block sql injection attempts') do |req|
      req.params.any? { |_k, v| v.to_s =~ /(\bunion\b|\bselect\b|\bfrom\b|\bwhere\b)/i }
    end

    # Throttle all requests by IP
    throttle('req/ip', limit: ENV.fetch('RACK_ATTACK_LIMIT', 300).to_i,
                       period: ENV.fetch('RACK_ATTACK_PERIOD', 300).to_i, &:ip)

    # Throttle login attempts
    throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
      req.ip if req.path == '/api/v1/auth/login' && req.post?
    end

    # Throttle registration — 10/hour per IP to allow shared NAT (office, household)
    throttle('register/ip', limit: 10, period: 1.hour) do |req|
      req.ip if req.path == '/api/v1/auth/register' && req.post?
    end

    # Throttle player self-registration (ArenaBR) — 5/hour, mais restrito que staff
    throttle('player-register/ip', limit: 5, period: 1.hour) do |req|
      req.ip if req.path == '/api/v1/auth/player-register' && req.post?
    end

    # Throttle player login — mesma política que login de staff
    throttle('player-logins/ip', limit: 5, period: 20.seconds) do |req|
      req.ip if req.path == '/api/v1/auth/player-login' && req.post?
    end

    # Throttle password reset requests
    throttle('password_reset/ip', limit: 5, period: 1.hour) do |req|
      req.ip if req.path == '/api/v1/auth/forgot-password' && req.post?
    end

    # Throttle public lobby endpoint — unauthenticated, runs heavy joins
    throttle('lobby/ip', limit: 60, period: 1.minute) do |req|
      req.ip if req.path == '/api/v1/scrims/lobby' && req.get?
    end

    # Throttle API requests per authenticated user
    throttle('req/authenticated_user', limit: 1000, period: 1.hour) do |req|
      req.env['rack.jwt.payload']['user_id'] if req.env['rack.jwt.payload']
    end

    # Add Retry-After header to throttled responses so clients can self-throttle
    Rack::Attack.throttled_responder = lambda do |req|
      match_data  = req.env['rack.attack.match_data']
      period      = match_data[:period].to_i
      epoch_time  = match_data[:epoch_time].to_i
      retry_after = period - (epoch_time % period)

      headers = {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      }
      body = { error: { code: 'RATE_LIMITED', message: 'Too many requests. Please retry later.' } }.to_json
      [429, headers, [body]]
    end

    # Log blocked and throttled requests
    ActiveSupport::Notifications.subscribe('rack.attack') do |_name, _start, _finish, _request_id, payload|
      req = payload[:request]

      # Only log if request was actually blocked or throttled
      if %i[throttle blocklist].include?(req.env['rack.attack.match_type'])
        discriminator = req.env['rack.attack.matched']
        Rails.logger.warn "[Rack::Attack] #{req.env['rack.attack.match_type'].to_s.capitalize} #{discriminator}: #{req.env['REQUEST_METHOD']} #{req.url} from #{req.ip}"
      end
    end
  end
end
