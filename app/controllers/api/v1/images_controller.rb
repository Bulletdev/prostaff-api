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
    # @example Usage from frontend
    #   <img src="https://api.prostaff.gg/api/v1/images/proxy?url=https://upload.wikimedia.org/..." />
    class ImagesController < BaseController
      skip_before_action :authenticate_request!, only: [:proxy]

      ALLOWED_DOMAINS = [
        'upload.wikimedia.org',
        'ddragon.leagueoflegends.com',
        'raw.communitydragon.org',
        'static.wikia.nocookie.net',
        'commons.wikimedia.org'
      ].freeze

      HTTP_TIMEOUT_OPTIONS = { open_timeout: 5, read_timeout: 10 }.freeze

      # GET /api/v1/images/proxy
      # Proxies and caches external images
      #
      # @param url [String] The external image URL to proxy
      # @return [Binary] The image data with appropriate content-type
      def proxy
        url = params[:url]
        return render_invalid_url unless valid_image_url?(url)

        cached_data = fetch_cached_image(url)
        return render_fetch_error(cached_data[:error]) if cached_data[:error]

        send_image_data(cached_data, url)
      rescue StandardError => e
        handle_proxy_error(e)
      end

      private

      # Validates if the URL is from an allowed domain
      def valid_image_url?(url)
        return false if url.blank?

        uri = URI.parse(url)
        ALLOWED_DOMAINS.any? { |domain| uri.host&.include?(domain) }
      rescue URI::InvalidURIError
        false
      end

      # Fetches image from cache or external source
      def fetch_cached_image(url)
        cache_key = "image_proxy:#{Digest::SHA256.hexdigest(url)}"
        Rails.cache.fetch(cache_key, expires_in: 7.days) do
          fetch_external_image(url)
        end
      end

      # Fetches image from external URL
      def fetch_external_image(url)
        uri = URI.parse(url)
        response = perform_http_request(uri)
        process_http_response(response)
      rescue StandardError => e
        Rails.logger.error("Failed to fetch image from #{url}: #{e.message}")
        { error: e.message }
      end

      # Performs HTTP request to fetch image
      def perform_http_request(uri)
        Net::HTTP.start(uri.host, uri.port,
                        use_ssl: uri.scheme == 'https',
                        **HTTP_TIMEOUT_OPTIONS) do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
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

      # Sends image data to client
      def send_image_data(cached_data, url)
        send_data cached_data[:body],
                  type: cached_data[:content_type],
                  disposition: 'inline',
                  filename: File.basename(URI.parse(url).path)
      end

      # Handles proxy errors
      def handle_proxy_error(error)
        Rails.logger.error("Image proxy error: #{error.message}")
        render json: { error: 'Failed to fetch image' }, status: :internal_server_error
      end
    end
  end
end
