# frozen_string_literal: true

module Middleware
  # Rack middleware that injects HTTP security headers into every response.
  #
  # Rationale: config.action_dispatch.default_headers is unreliable in Rails API
  # mode behind Traefik/Cloudflare. This middleware guarantees headers are set at
  # the Rack layer, before the response leaves the application server.
  #
  # Headers applied (only when not already set by a controller):
  #   - Strict-Transport-Security: enforce HTTPS for 1 year + subdomains
  #   - X-Frame-Options: block clickjacking
  #   - X-Content-Type-Options: prevent MIME sniffing
  #   - Content-Security-Policy: deny all content sources (API returns JSON only)
  #   - Referrer-Policy: do not leak full URL to third parties
  #   - Permissions-Policy: disable camera/mic/geolocation browser features
  class SecurityHeaders
    HEADERS = {
      'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
      'X-Frame-Options' => 'DENY',
      'X-Content-Type-Options' => 'nosniff',
      'Content-Security-Policy' => "default-src 'none'; frame-ancestors 'none'",
      'Referrer-Policy' => 'strict-origin-when-cross-origin',
      'Permissions-Policy' => 'geolocation=(), camera=(), microphone=(), payment=()'
    }.freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      # Capture path before @app.call — Rails mutates PATH_INFO during routing
      path = env['PATH_INFO']
      status, headers, body = @app.call(env)

      if path.start_with?('/sidekiq')
        # Rack 3 normalises header keys to lowercase; delete both variants to be safe.
        # Sidekiq::Web already injects its own permissive CSP with nonce, so we just
        # remove the restrictive one added by ActionDispatch / our own HEADERS hash.
        headers.delete('Content-Security-Policy')
        headers.delete('content-security-policy')
        return [status, headers, body]
      end

      HEADERS.each { |key, value| headers[key] ||= value }
      [status, headers, body]
    end
  end
end
