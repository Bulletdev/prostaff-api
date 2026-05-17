# frozen_string_literal: true

require 'net/http'

module Api
  module V1
    # WalletController
    #
    # Transparent proxy between ArenaBR frontend and the ProPay service.
    # All requests are forwarded with the caller's Authorization header so
    # ProPay can validate the same JWT (shared INTERNAL_JWT_SECRET is NOT
    # used here — the user/player Bearer token is passed through as-is).
    #
    # Authentication is enforced by BaseController before any action runs.
    #
    # @example Get wallet balance
    #   GET /api/v1/wallet
    #   Authorization: Bearer <user_token>
    #
    # @example Submit a deposit
    #   POST /api/v1/wallet/deposit
    #   Authorization: Bearer <user_token>
    #   Idempotency-Key: <uuid>
    #   Body: { "amount": 5000 }
    class WalletController < BaseController
      # Returns the current user's wallet (balance, currency, status).
      #
      # @return [JSON] Proxied response from ProPay
      def show
        proxy_to_propay(:get, '/v1/wallet')
      end

      # Returns a paginated list of wallet transactions.
      #
      # @return [JSON] Proxied response from ProPay
      def transactions
        proxy_to_propay(:get, '/v1/wallet/transactions')
      end

      # Initiates a deposit request (PIX or other method).
      #
      # @return [JSON] Proxied response from ProPay
      def deposit
        proxy_to_propay(
          :post,
          '/v1/wallet/deposit',
          body: request.raw_post,
          idempotency_key: request.headers['Idempotency-Key']
        )
      end

      # Returns the status of a specific charge by txid.
      #
      # @param txid [String] The transaction ID (URL param)
      # @return [JSON] Proxied response from ProPay
      def charge_status
        proxy_to_propay(:get, "/v1/charges/#{params[:txid]}")
      end

      # Creates a payout request.
      #
      # @return [JSON] Proxied response from ProPay
      def create_payout
        proxy_to_propay(
          :post,
          '/v1/wallet/payouts',
          body: request.raw_post,
          idempotency_key: request.headers['Idempotency-Key']
        )
      end

      # Returns the status of a specific payout.
      #
      # @param id [String] The payout ID (URL param)
      # @return [JSON] Proxied response from ProPay
      def payout_status
        proxy_to_propay(:get, "/v1/wallet/payouts/#{params[:id]}")
      end

      private

      # Forwards the request to ProPay and renders the response verbatim.
      #
      # @param method [Symbol] HTTP method (:get or :post)
      # @param path [String] ProPay endpoint path
      # @param body [String, nil] Raw request body (JSON string)
      # @param idempotency_key [String, nil] Value for Idempotency-Key header
      # @return [void]
      def proxy_to_propay(method, path, body: nil, idempotency_key: nil)
        propay_url = ENV.fetch('PROPAY_URL', 'http://propay:5555')
        uri = URI("#{propay_url}#{path}")

        http = build_http_client(uri)
        http_request = build_http_request(method, uri, body, idempotency_key)

        response = http.request(http_request)
        render json: JSON.parse(response.body), status: response.code.to_i
      rescue Net::OpenTimeout, Net::ReadTimeout
        render json: { error: { message: 'ProPay timeout' } }, status: :gateway_timeout
      rescue StandardError => e
        Rails.logger.error("[WALLET] ProPay proxy error for #{path}: #{e.message}")
        render json: { error: { message: e.message } }, status: :bad_gateway
      end

      # Builds a configured Net::HTTP instance.
      #
      # @param uri [URI] Target URI
      # @return [Net::HTTP]
      def build_http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 5
        http.read_timeout = 10
        http
      end

      # Builds the HTTP request object with all required headers.
      #
      # @param method [Symbol] :get or :post
      # @param uri [URI] Target URI
      # @param body [String, nil] Raw JSON body
      # @param idempotency_key [String, nil] Idempotency-Key header value
      # @return [Net::HTTPRequest]
      def build_http_request(method, uri, body, idempotency_key)
        req_class = http_method_class(method)
        http_request = req_class.new(uri.request_uri, build_headers(idempotency_key))
        http_request.body = body if body.present?
        http_request
      end

      # Maps a symbol to a Net::HTTP request class.
      #
      # @param method [Symbol] :get or :post
      # @return [Class]
      def http_method_class(method)
        { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method)
      end

      # Builds the forwarded headers hash.
      #
      # @param idempotency_key [String, nil]
      # @return [Hash]
      def build_headers(idempotency_key)
        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => request.headers['Authorization'],
          'User-Agent' => 'prostaff-api/1.0'
        }
        headers['Idempotency-Key'] = idempotency_key if idempotency_key.present?
        headers
      end
    end
  end
end
