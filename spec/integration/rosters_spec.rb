# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Rosters API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  # ---------------------------------------------------------------------------
  # Roster Actions
  # ---------------------------------------------------------------------------

  path '/api/v1/rosters/free-agents' do
    get 'List free agents available for hiring' do
      tags 'Rosters'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :role, in: :query, type: :string, required: false
      parameter name: :region, in: :query, type: :string, required: false

      response '200', 'free agents returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     free_agents: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/Player' }
                     },
                     pagination: { '$ref' => '#/components/schemas/Pagination' }
                   }
                 }
               }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/rosters/statistics' do
    get 'Get roster statistics for the organization' do
      tags 'Rosters'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'roster statistics returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     total_players: { type: :integer },
                     active: { type: :integer },
                     inactive: { type: :integer },
                     benched: { type: :integer },
                     trial: { type: :integer },
                     avg_age: { type: :number, nullable: true },
                     roles_breakdown: { type: :object }
                   }
                 }
               }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/rosters/hire/{scouting_target_id}' do
    post 'Hire a scouted player to the roster' do
      tags 'Rosters'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :scouting_target_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          status: {
            type: :string,
            enum: %w[active inactive trial],
            example: 'trial'
          },
          notes: { type: :string, nullable: true }
        },
        required: ['status']
      }

      response '201', 'player hired' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     player: { '$ref' => '#/components/schemas/Player' }
                   }
                 }
               }
        let(:scouting_target_id) { 'nonexistent' }
        let(:body) { { status: 'trial' } }
        run_test!
      end

      response '404', 'scouting target not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:scouting_target_id) { 'nonexistent' }
        let(:body) { { status: 'trial' } }
        run_test!
      end

      response '422', 'validation error' do
        schema '$ref' => '#/components/schemas/Error'
        let(:scouting_target_id) { 'nonexistent' }
        let(:body) { { status: 'invalid_status' } }
        run_test!
      end
    end
  end

  path '/api/v1/rosters/remove/{player_id}' do
    post 'Remove a player from the roster' do
      tags 'Rosters'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :player_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          reason: { type: :string, example: 'Contract ended' }
        },
        required: ['reason']
      }

      response '200', 'player removed from roster' do
        schema type: :object,
               properties: { message: { type: :string } }
        let(:player_id) { create(:player, organization: organization).id }
        let(:body) { { reason: 'Contract ended' } }
        run_test!
      end

      response '404', 'player not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:player_id) { 'nonexistent' }
        let(:body) { { reason: 'Contract ended' } }
        run_test!
      end
    end
  end
end
