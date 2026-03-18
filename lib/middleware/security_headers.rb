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
      'X-Frame-Options'           => 'DENY',
      'X-Content-Type-Options'    => 'nosniff',
      'Content-Security-Policy'   => "default-src 'none'; frame-ancestors 'none'",
      'Referrer-Policy'           => 'strict-origin-when-cross-origin',
      'Permissions-Policy'        => 'geolocation=(), camera=(), microphone=(), payment=()'
    }.freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      HEADERS.each { |key, value| headers[key] ||= value }
      [status, headers, body]
    end
  end
end
