require 'swagger_helper'

RSpec.describe 'Players API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  path '/api/v1/players' do
    get 'List all players' do
      tags 'Players'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'
      parameter name: :role, in: :query, type: :string, required: false, description: 'Filter by role'
      parameter name: :status, in: :query, type: :string, required: false, description: 'Filter by status'
      parameter name: :search, in: :query, type: :string, required: false, description: 'Search by summoner name or real name'

      response '200', 'players found' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                players: {
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

    post 'Create a player' do
      tags 'Players'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :player, in: :body, schema: {
        type: :object,
        properties: {
          player: {
            type: :object,
            properties: {
              summoner_name: { type: :string },
              real_name: { type: :string },
              role: { type: :string, enum: %w[top jungle mid adc support] },
              status: { type: :string, enum: %w[active inactive benched trial] },
              jersey_number: { type: :integer },
              birth_date: { type: :string, format: :date },
              country: { type: :string }
            },
            required: %w[summoner_name role]
          }
        }
      }

      response '201', 'player created' do
        let(:player) do
          {
            player: {
              summoner_name: 'TestPlayer',
              real_name: 'Test User',
              role: 'mid',
              status: 'active'
            }
          }
        end

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                player: { '$ref' => '#/components/schemas/Player' }
              }
            }
          }

        run_test!
      end

      response '422', 'invalid request' do
        let(:player) { { player: { summoner_name: '' } } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/players/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Player ID'

    get 'Show player details' do
      tags 'Players'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'player found' do
        let(:id) { create(:player, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                player: { '$ref' => '#/components/schemas/Player' }
              }
            }
          }

        run_test!
      end

      response '404', 'player not found' do
        let(:id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    patch 'Update a player' do
      tags 'Players'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :player, in: :body, schema: {
        type: :object,
        properties: {
          player: {
            type: :object,
            properties: {
              summoner_name: { type: :string },
              real_name: { type: :string },
              status: { type: :string }
            }
          }
        }
      }

      response '200', 'player updated' do
        let(:id) { create(:player, organization: organization).id }
        let(:player) { { player: { summoner_name: 'UpdatedName' } } }

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                player: { '$ref' => '#/components/schemas/Player' }
              }
            }
          }

        run_test!
      end
    end

    delete 'Delete a player' do
      tags 'Players'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'player deleted' do
        let(:user) { create(:user, :owner, organization: organization) }
        let(:id) { create(:player, organization: organization).id }

        schema type: :object,
          properties: {
            message: { type: :string }
          }

        run_test!
      end
    end
  end

  path '/api/v1/players/{id}/stats' do
    parameter name: :id, in: :path, type: :string, description: 'Player ID'

    get 'Get player statistics' do
      tags 'Players'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'statistics retrieved' do
        let(:id) { create(:player, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                player: { '$ref' => '#/components/schemas/Player' },
                overall: { type: :object },
                recent_form: { type: :object },
                champion_pool: { type: :array },
                performance_by_role: { type: :array }
              }
            }
          }

        run_test!
      end
    end
  end
end
