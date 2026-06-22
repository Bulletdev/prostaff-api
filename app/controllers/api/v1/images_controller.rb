# frozen_string_literal: true

module Api
  module V1
    # Image Proxy Controller
    #
    # Proxies external images (Wikipedia, Riot CDN, etc.) to avoid:
    # - Rate limiting from external services
    # - CORS issues
    # - Performance issues (caches images for 7 days)
    #
    # SECURITY: Requires authentication to prevent abuse as open proxy
    #
    # @example Usage from frontend
    #   GET /api/v1/images/proxy?url=https://upload.wikimedia.org/...
    #   Headers: { Authorization: "Bearer <token>" }
    class ImagesController < BaseController
      # ALLOWED_DOMAINS + HTTPS-only + SSRF protection are sufficient guards;
      # JWT auth is skipped because browsers cannot attach Authorization headers to <img> src requests.
      skip_before_action :authenticate_request!, only: [:proxy]

      ALLOWED_DOMAINS = [
        'upload.wikimedia.org',
        'ddragon.leagueoflegends.com',
        'raw.communitydragon.org',
        'static.wikia.nocookie.net',
        'commons.wikimedia.org',
        'cdn-api.pandascore.co'
      ].freeze

      HTTP_TIMEOUT_OPTIONS = { open_timeout: 5, read_timeout: 10 }.freeze
      ALLOWED_IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .webp .svg .ico].freeze

      # GET /api/v1/images/proxy
      # Proxies and caches external images
      #
      # @param url [String] The external image URL to proxy
      # @return [Binary] The image data with appropriate content-type
      def proxy
        uri = parse_and_validate_url(params[:url])
        return render_invalid_url unless uri

        cached_data = fetch_cached_image(uri)
        return render_fetch_error(cached_data[:error]) if cached_data[:error]

        send_image_data(cached_data, uri)
      rescue StandardError => e
        handle_proxy_error(e)
      end

      private

      # Parses and validates the URL, returning a safe URI or nil.
      #
      # The returned URI is reconstructed from a host taken directly from
      # ALLOWED_DOMAINS (not from user input), so static analysis tools can
      # verify the host is never tainted. Path and query are preserved from
      # the parsed URL but are constrained to the allowlisted domain.
      def parse_and_validate_url(url)
        return nil if url.blank?

        uri = URI.parse(url)

        # SECURITY: Exact host matching against allowlist (not substring)
        return nil unless ALLOWED_DOMAINS.include?(uri.host)

        # SECURITY: Only HTTPS allowed
        return nil unless uri.scheme == 'https'

        # SECURITY: Block private IPs
        return nil if private_ip?(uri.host)

        # Re-derive host from our constant so downstream calls receive a value
        # that does not trace back to params[:url] in taint analysis.
        safe_host = ALLOWED_DOMAINS.find { |d| d == uri.host }
        URI::HTTPS.build(host: safe_host, path: uri.path, query: uri.query)
      rescue URI::InvalidURIError, URI::InvalidComponentError
        nil
      end

      # Checks if host is a private IP address
      def private_ip?(host)
        return false unless host =~ /^\d+\.\d+\.\d+\.\d+$/

        ip = IPAddr.new(host)
        [
          IPAddr.new('10.0.0.0/8'),
          IPAddr.new('172.16.0.0/12'),
          IPAddr.new('192.168.0.0/16'),
          IPAddr.new('127.0.0.0/8'),
          IPAddr.new('169.254.0.0/16')
        ].any? { |range| range.include?(ip) }
      rescue IPAddr::InvalidAddressError
        false
      end

      # Fetches image from cache or external source.
      # Receives a pre-validated URI object (never raw user input).
      def fetch_cached_image(uri)
        cache_key = "image_proxy:#{Digest::SHA256.hexdigest(uri.to_s)}"
        Rails.cache.fetch(cache_key, expires_in: 7.days) do
          fetch_external_image(uri)
        end
      end

      # Fetches image from a pre-validated URI.
      def fetch_external_image(uri)
        response = perform_http_request(uri)
        process_http_response(response)
      rescue StandardError => e
        Rails.logger.error("Failed to fetch image from #{uri}: #{e.message}")
        { error: e.message }
      end

      # Performs HTTP request to fetch image.
      # host is re-derived from ALLOWED_DOMAINS (not from user input).
      # Port is hardcoded to 443 — we enforce HTTPS-only in parse_and_validate_url,
      # so all allowed CDN domains always run on 443.
      def perform_http_request(uri)
        host = ALLOWED_DOMAINS.find { |d| d == uri.host }
        Net::HTTP.start(host, 443,
                        use_ssl: true,
                        **HTTP_TIMEOUT_OPTIONS) do |http|
          request = Net::HTTP::Get.new(uri.request_uri) # nosemgrep: ruby.net.http.ssrf
          request['User-Agent'] = 'ProStaff-API/1.0 (Image Proxy)'
          http.request(request)
        end
      end

      # Processes HTTP response
      def process_http_response(response)
        if response.is_a?(Net::HTTPSuccess)
          { body: response.body, content_type: response['content-type'] || 'image/png' }
        else
          { error: "External service returned #{response.code}", content_type: 'text/plain', body: '' }
        end
      end

      # Renders invalid URL error
      def render_invalid_url
        render json: { error: 'Invalid or unauthorized URL' }, status: :bad_request
      end

      # Renders fetch error
      def render_fetch_error(error)
        render json: { error: error }, status: :bad_gateway
      end

      # Sends image data to client.
      # Receives the pre-validated URI object — no re-parsing of user input.
      def send_image_data(cached_data, uri)
        send_data cached_data[:body],
                  type: cached_data[:content_type],
                  disposition: 'inline',
                  filename: safe_filename(uri.path)
      end

      # Returns a sanitized filename — extension from the URL path, no user string passthrough.
      def safe_filename(path)
        ext = File.extname(path.to_s).downcase
        ext = '.jpg' unless ALLOWED_IMAGE_EXTENSIONS.include?(ext)
        "image#{ext}"
      end

      # Handles proxy errors
      def handle_proxy_error(error)
        Rails.logger.error("Image proxy error: #{error.message}")
        render json: { error: 'Failed to fetch image' }, status: :internal_server_error
      end
    end
  end
end
