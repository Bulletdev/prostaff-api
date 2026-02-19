# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Competitive API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  # ---------------------------------------------------------------------------
  # Competitive Matches (PandaScore imported)
  # ---------------------------------------------------------------------------

  path '/api/v1/competitive-matches' do
    get 'List competitive matches' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :status, in: :query, type: :string, required: false,
                description: 'Filter by status (upcoming, past)'

      response '200', 'competitive matches returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     matches: { type: :array, items: { type: :object } },
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

  path '/api/v1/competitive-matches/{id}' do
    get 'Get competitive match details' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'competitive match found' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Pro Matches
  # ---------------------------------------------------------------------------

  path '/api/v1/competitive/pro-matches' do
    get 'List all pro matches' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :league, in: :query, type: :string, required: false
      parameter name: :team, in: :query, type: :string, required: false

      response '200', 'pro matches returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     matches: { type: :array, items: { type: :object } },
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

  path '/api/v1/competitive/pro-matches/upcoming' do
    get 'Get upcoming pro matches' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :limit, in: :query, type: :integer, required: false

      response '200', 'upcoming pro matches returned' do
        schema type: :object,
               properties: { data: { type: :array, items: { type: :object } } }
        run_test!
      end
    end
  end

  path '/api/v1/competitive/pro-matches/past' do
    get 'Get past pro matches' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :limit, in: :query, type: :integer, required: false

      response '200', 'past pro matches returned' do
        schema type: :object,
               properties: { data: { type: :array, items: { type: :object } } }
        run_test!
      end
    end
  end

  path '/api/v1/competitive/pro-matches/{id}' do
    get 'Get pro match details' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'pro match found' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  path '/api/v1/competitive/pro-matches/refresh' do
    post 'Refresh pro matches from PandaScore' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'refresh triggered' do
        schema type: :object,
               properties: { data: { type: :object } }
        run_test!
      end
    end
  end

  path '/api/v1/competitive/pro-matches/import' do
    post 'Import a specific pro match from PandaScore' do
      tags 'Competitive'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          match_id: { type: :string, example: '12345' }
        },
        required: ['match_id']
      }

      response '200', 'match imported' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:body) { { match_id: '12345' } }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Draft Analysis
  # ---------------------------------------------------------------------------

  path '/api/v1/competitive/draft-comparison' do
    post 'Compare two team compositions' do
      tags 'Competitive'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          team_a: {
            type: :array,
            items: { type: :string },
            example: %w[Jinx Lulu Thresh Orianna Garen]
          },
          team_b: {
            type: :array,
            items: { type: :string },
            example: %w[Caitlyn Zyra Renekton Azir Lee\ Sin]
          }
        },
        required: %w[team_a team_b]
      }

      response '200', 'draft comparison returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     team_a_score: { type: :number },
                     team_b_score: { type: :number },
                     analysis: { type: :string }
                   }
                 }
               }
        let(:body) { { team_a: %w[Jinx Lulu Thresh Orianna Garen], team_b: %w[Caitlyn Zyra Renekton Azir Graves] } }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Meta
  # ---------------------------------------------------------------------------

  path '/api/v1/competitive/meta/{role}' do
    get 'Get meta champions by role' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :role, in: :path, type: :string, required: true,
                description: 'Role: top, jungle, mid, adc, support'

      response '200', 'meta champions returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       champion: { type: :string },
                       pick_rate: { type: :number },
                       win_rate: { type: :number }
                     }
                   }
                 }
               }
        let(:role) { 'mid' }
        run_test!
      end

      response '422', 'invalid role' do
        schema '$ref' => '#/components/schemas/Error'
        let(:role) { 'invalid_role' }
        run_test!
      end
    end
  end

  path '/api/v1/competitive/composition-winrate' do
    get 'Get composition win rate statistics' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :champions, in: :query, type: :string, required: false,
                description: 'Comma-separated champion names'

      response '200', 'composition win rate returned' do
        schema type: :object,
               properties: { data: { type: :object } }
        run_test!
      end
    end
  end

  path '/api/v1/competitive/counters' do
    get 'Get champion counter suggestions' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :champion, in: :query, type: :string, required: true,
                description: 'Champion name to find counters for'
      parameter name: :role, in: :query, type: :string, required: false

      response '200', 'counters returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       counter_champion: { type: :string },
                       win_rate_vs: { type: :number }
                     }
                   }
                 }
               }
        let(:champion) { 'Zed' }
        run_test!
      end
    end
  end
end
