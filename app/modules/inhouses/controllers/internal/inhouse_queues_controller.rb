# frozen_string_literal: true

module Inhouses
  module Controllers
    module Internal
      # Internal endpoint for prostaff-events startup reconciliation.
      # Returns all InhouseQueues in check_in state with a future deadline.
      # Authenticated via INTERNAL_JWT_SECRET — not user JWT.
      class InhouseQueuesController < ApplicationController
        before_action :verify_internal_token

        # GET /internal/api/inhouse_queues/active
        def active
          queues = InhouseQueue.check_in
                               .where('check_in_deadline > ?', Time.current)
                               .includes(inhouse_queue_entries: :player)

          render json: {
            queues: queues.map { |q| serialize_queue(q) }
          }
        end

        private

        def verify_internal_token
          auth_header = request.headers['Authorization'].to_s
          token = auth_header.sub('Bearer ', '')

          render json: { error: 'unauthorized' }, status: :unauthorized and return unless token.present?

          payload = JwtService.decode(token)

          render json: { error: 'forbidden' }, status: :forbidden and return unless payload[:type] == 'internal'
        rescue JwtService::AuthenticationError
          render json: { error: 'unauthorized' }, status: :unauthorized
        end

        def serialize_queue(queue)
          {
            id: queue.id,
            organization_id: queue.organization_id,
            status: queue.status,
            check_in_deadline: queue.check_in_deadline&.iso8601,
            entries: queue.inhouse_queue_entries.map do |e|
              {
                player_id: e.player_id,
                role: e.role,
                checked_in: e.checked_in
              }
            end
          }
        end
      end
    end
  end
end
