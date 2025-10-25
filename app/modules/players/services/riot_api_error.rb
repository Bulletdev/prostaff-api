# frozen_string_literal: true

module Players
  module Services
    # Custom exception for Riot API errors with status code tracking
    class RiotApiError < StandardError
      attr_accessor :status_code, :response_body

      def initialize(message = nil)
        super
        @status_code = nil
        @response_body = nil
      end

      def not_found?
        status_code == 404
      end

      def rate_limited?
        status_code == 429
      end

      def server_error?
        status_code >= 500
      end
    end
  end
end
