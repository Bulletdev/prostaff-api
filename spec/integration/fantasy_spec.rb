# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Fantasy API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{JwtService.encode({ user_id: user.id })}" }

  # ---------------------------------------------------------------------------
  # Fantasy Waitlist
  # ---------------------------------------------------------------------------

  path '/api/v1/fantasy/waitlist' do
    post 'Join the fantasy feature waitlist' do
      tags 'Fantasy'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: {
            type: :string,
            format: :email,
            example: 'coach@team.gg'
          },
          notes: {
            type: :string,
            nullable: true,
            example: 'Interested in using fantasy for team building decisions'
          }
        },
        required: ['email']
      }

      response '201', 'added to waitlist' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     email: { type: :string },
                     position: { type: :integer },
                     created_at: { type: :string, format: 'date-time' }
                   }
                 }
               }
        let(:body) { { email: 'coach@team.gg' } }
        run_test!
      end

      response '422', 'already on waitlist or validation error' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) { { email: 'invalid-email' } }
        run_test!
      end

      # Public endpoint — no authentication required
    end
  end

  path '/api/v1/fantasy/waitlist/stats' do
    get 'Get fantasy waitlist statistics' do
      tags 'Fantasy'
      produces 'application/json'

      response '200', 'waitlist stats returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     total: { type: :integer },
                     last_7_days: { type: :integer }
                   }
                 }
               }
        run_test!
      end
    end
  end
end
