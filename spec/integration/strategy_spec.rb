# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Strategy API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  # ---------------------------------------------------------------------------
  # Draft Plans
  # ---------------------------------------------------------------------------

  path '/api/v1/strategy/draft-plans' do
    get 'List draft plans' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :status, in: :query, type: :string, required: false,
                description: 'Filter by status: active, inactive'

      response '200', 'draft plans returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     draft_plans: { type: :array, items: { type: :object } },
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

    post 'Create a new draft plan' do
      tags 'Strategy'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :draft_plan, in: :body, schema: {
        type: :object,
        properties: {
          draft_plan: {
            type: :object,
            properties: {
              name: { type: :string, example: 'vs Tempo Storm — Blue Side' },
              opponent_name: { type: :string, example: 'Tempo Storm' },
              side: { type: :string, enum: %w[blue red], example: 'blue' },
              picks: {
                type: :array,
                items: { type: :string },
                example: %w[Jinx Lulu Thresh Orianna Garen]
              },
              bans: {
                type: :array,
                items: { type: :string },
                example: %w[Zed Katarina]
              },
              notes: { type: :string, nullable: true }
            },
            required: %w[name side]
          }
        }
      }

      response '201', 'draft plan created' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:draft_plan) do
          {
            draft_plan: {
              name: 'vs Rival — Blue Side',
              side: 'blue',
              picks: %w[Jinx Lulu Thresh Orianna Garen],
              bans: %w[Zed Katarina]
            }
          }
        end
        run_test!
      end

      response '422', 'validation error' do
        schema '$ref' => '#/components/schemas/Error'
        let(:draft_plan) { { draft_plan: { name: '' } } }
        run_test!
      end
    end
  end

  path '/api/v1/strategy/draft-plans/{id}' do
    get 'Get draft plan details' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'draft plan found' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end

      response '404', 'draft plan not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { 'nonexistent' }
        run_test!
      end
    end

    patch 'Update a draft plan' do
      tags 'Strategy'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :draft_plan, in: :body, schema: {
        type: :object,
        properties: {
          draft_plan: {
            type: :object,
            properties: {
              name: { type: :string },
              notes: { type: :string },
              picks: { type: :array, items: { type: :string } },
              bans: { type: :array, items: { type: :string } }
            }
          }
        }
      }

      response '200', 'draft plan updated' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        let(:draft_plan) { { draft_plan: { notes: 'Updated notes' } } }
        run_test!
      end
    end

    delete 'Delete a draft plan' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'draft plan deleted' do
        schema type: :object,
               properties: { message: { type: :string } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  path '/api/v1/strategy/draft-plans/{id}/analyze' do
    post 'Analyze a draft plan' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'draft analysis returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     strengths: { type: :array, items: { type: :string } },
                     weaknesses: { type: :array, items: { type: :string } },
                     win_condition: { type: :string },
                     score: { type: :number }
                   }
                 }
               }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  path '/api/v1/strategy/draft-plans/{id}/activate' do
    patch 'Activate a draft plan' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'draft plan activated' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  path '/api/v1/strategy/draft-plans/{id}/deactivate' do
    patch 'Deactivate a draft plan' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'draft plan deactivated' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tactical Boards
  # ---------------------------------------------------------------------------

  path '/api/v1/strategy/tactical-boards' do
    get 'List tactical boards' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'tactical boards returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     tactical_boards: { type: :array, items: { type: :object } },
                     pagination: { '$ref' => '#/components/schemas/Pagination' }
                   }
                 }
               }
        run_test!
      end
    end

    post 'Create a tactical board' do
      tags 'Strategy'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :tactical_board, in: :body, schema: {
        type: :object,
        properties: {
          tactical_board: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Dragon Control Setup' },
              description: { type: :string, nullable: true },
              board_data: { type: :object, description: 'JSON state of the board canvas' }
            },
            required: ['name']
          }
        }
      }

      response '201', 'tactical board created' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:tactical_board) { { tactical_board: { name: 'Dragon Control Setup', board_data: {} } } }
        run_test!
      end
    end
  end

  path '/api/v1/strategy/tactical-boards/{id}' do
    get 'Get tactical board details' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'tactical board found' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end

    patch 'Update a tactical board' do
      tags 'Strategy'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :tactical_board, in: :body, schema: {
        type: :object,
        properties: {
          tactical_board: {
            type: :object,
            properties: {
              name: { type: :string },
              description: { type: :string },
              board_data: { type: :object }
            }
          }
        }
      }

      response '200', 'tactical board updated' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        let(:tactical_board) { { tactical_board: { name: 'Updated Board' } } }
        run_test!
      end
    end

    delete 'Delete a tactical board' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'tactical board deleted' do
        schema type: :object,
               properties: { message: { type: :string } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  path '/api/v1/strategy/tactical-boards/{id}/statistics' do
    get 'Get tactical board usage statistics' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'tactical board statistics returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     views: { type: :integer },
                     last_modified: { type: :string, format: 'date-time' }
                   }
                 }
               }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Assets
  # ---------------------------------------------------------------------------

  path '/api/v1/strategy/assets/champion/{champion_name}' do
    get 'Get champion assets for the tactical board' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :champion_name, in: :path, type: :string, required: true,
                example: 'Jinx'

      response '200', 'champion assets returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     name: { type: :string },
                     icon_url: { type: :string },
                     splash_url: { type: :string }
                   }
                 }
               }
        let(:champion_name) { 'Jinx' }
        run_test!
      end
    end
  end

  path '/api/v1/strategy/assets/map' do
    get 'Get Summoners Rift map assets' do
      tags 'Strategy'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'map assets returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     map_url: { type: :string },
                     width: { type: :integer },
                     height: { type: :integer }
                   }
                 }
               }
        run_test!
      end
    end
  end
end
