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
      skip_before_action :authenticate_user!, only: [:proxy]

      # GET /api/v1/images/proxy
      # Proxies and caches external images
      #
      # @param url [String] The external image URL to proxy
      # @return [Binary] The image data with appropriate content-type
      def proxy
        url = params[:url]

        # Validate URL
        unless valid_image_url?(url)
          render json: { error: 'Invalid or unauthorized URL' }, status: :bad_request
          return
        end

        # Try to get from cache first
        cache_key = "image_proxy:#{Digest::MD5.hexdigest(url)}"
        cached_data = Rails.cache.fetch(cache_key, expires_in: 7.days) do
          fetch_external_image(url)
        end

        if cached_data[:error]
          render json: { error: cached_data[:error] }, status: :bad_gateway
          return
        end

        # Send the cached image
        send_data cached_data[:body],
                  type: cached_data[:content_type],
                  disposition: 'inline',
                  filename: File.basename(URI.parse(url).path)
      rescue StandardError => e
        Rails.logger.error("Image proxy error: #{e.message}")
        render json: { error: 'Failed to fetch image' }, status: :internal_server_error
      end

      private

      # Validates if the URL is from an allowed domain
      def valid_image_url?(url)
        return false if url.blank?

        uri = URI.parse(url)
        allowed_domains = [
          'upload.wikimedia.org',
          'ddragon.leagueoflegends.com',
          'raw.communitydragon.org',
          'static.wikia.nocookie.net',
          'commons.wikimedia.org'
        ]

        allowed_domains.any? { |domain| uri.host&.include?(domain) }
      rescue URI::InvalidURIError
        false
      end

      # Fetches image from external URL
      def fetch_external_image(url)
        uri = URI.parse(url)

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                        open_timeout: 5, read_timeout: 10) do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          request['User-Agent'] = 'ProStaff-API/1.0 (Image Proxy)'

          response = http.request(request)

          if response.is_a?(Net::HTTPSuccess)
            {
              body: response.body,
              content_type: response['content-type'] || 'image/png'
            }
          else
            {
              error: "External service returned #{response.code}",
              content_type: 'text/plain',
              body: ''
            }
          end
        end
      rescue StandardError => e
        Rails.logger.error("Failed to fetch image from #{url}: #{e.message}")
        { error: e.message }
      end
    end
  end
end
