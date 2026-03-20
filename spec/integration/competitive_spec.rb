# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Competitive API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :owner, organization: organization) }
  let(:Authorization) { "Bearer #{JwtService.encode({ user_id: user.id })}" }

  # ---------------------------------------------------------------------------
  # Competitive Matches (PandaScore imported - stored locally)
  # ---------------------------------------------------------------------------

  path '/api/v1/competitive/pro-matches' do
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

  path '/api/v1/competitive/pro-matches/{id}' do
    get 'Get competitive match details' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'competitive match found' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:competitive_match) { create(:competitive_match, organization: organization) }
        let(:id) { competitive_match.id }
        run_test!
      end

      response '404', 'competitive match not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Pro Matches
  # ---------------------------------------------------------------------------

  path '/api/v1/competitive/pro-matches/upcoming' do
    get 'Get upcoming pro matches' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :limit, in: :query, type: :integer, required: false

      response '200', 'upcoming pro matches returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     matches: { type: :array, items: { type: :object } },
                     source: { type: :string },
                     cached: { type: :boolean }
                   }
                 }
               }
        before do
          allow_any_instance_of(PandascoreService).to receive(:fetch_upcoming_matches).and_return([])
        end
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
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     matches: { type: :array, items: { type: :object } },
                     source: { type: :string },
                     cached: { type: :boolean }
                   }
                 }
               }
        before do
          allow_any_instance_of(PandascoreService).to receive(:fetch_past_matches).and_return([])
        end
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
        before do
          allow_any_instance_of(PandascoreService).to receive(:clear_cache)
        end
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

      response '404', 'match not found in PandaScore' do
        schema '$ref' => '#/components/schemas/Error'
        before do
          allow_any_instance_of(PandascoreService).to receive(:fetch_match_details)
            .and_raise(PandascoreService::NotFoundError)
        end
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
          our_picks: {
            type: :array,
            items: { type: :string },
            example: %w[Jinx Lulu Thresh Orianna Garen]
          },
          opponent_picks: {
            type: :array,
            items: { type: :string },
            example: %w[Caitlyn Zyra Renekton Azir Graves]
          }
        },
        required: %w[our_picks]
      }

      response '200', 'draft comparison returned' do
        schema type: :object,
               properties: {
                 data: { type: :object }
               }
        let(:body) { { our_picks: %w[Jinx Lulu Thresh Orianna Garen], opponent_picks: %w[Caitlyn Zyra Renekton Azir Graves] } }
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
                 data: { type: :object }
               }
        let(:role) { 'mid' }
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
        let(:champions) { 'Jinx,Lulu,Thresh,Orianna,Garen' }
        run_test!
      end
    end
  end

  path '/api/v1/competitive/counters' do
    get 'Get champion counter suggestions' do
      tags 'Competitive'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :opponent_pick, in: :query, type: :string, required: true,
                description: 'Champion name to find counters for'
      parameter name: :role, in: :query, type: :string, required: true,
                description: 'Role to counter'

      response '200', 'counters returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object
                 }
               }
        let(:opponent_pick) { 'Zed' }
        let(:role) { 'mid' }
        run_test!
      end
    end
  end
end
