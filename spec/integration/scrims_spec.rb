# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Scrims API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  # ---------------------------------------------------------------------------
  # Scrims
  # ---------------------------------------------------------------------------

  path '/api/v1/scrims/scrims' do
    get 'List all scrims' do
      tags 'Scrims'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :status, in: :query, type: :string, required: false
      parameter name: :start_date, in: :query, type: :string, required: false
      parameter name: :end_date, in: :query, type: :string, required: false

      response '200', 'scrims returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     scrims: { type: :array, items: { type: :object } },
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

    post 'Create a new scrim' do
      tags 'Scrims'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :scrim, in: :body, schema: {
        type: :object,
        properties: {
          scrim: {
            type: :object,
            properties: {
              scheduled_at: { type: :string, format: 'date-time', example: '2026-03-01T18:00:00Z' },
              opponent_team_id: { type: :string, format: :uuid, nullable: true },
              opponent_name: { type: :string, example: 'Team Rival' },
              format: { type: :string, enum: %w[bo1 bo3 bo5], example: 'bo3' },
              notes: { type: :string, nullable: true }
            },
            required: %w[scheduled_at format]
          }
        }
      }

      response '201', 'scrim created' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:scrim) do
          {
            scrim: {
              scheduled_at: '2026-03-01T18:00:00Z',
              opponent_name: 'Team Rival',
              format: 'bo3'
            }
          }
        end
        run_test!
      end

      response '422', 'validation error' do
        schema '$ref' => '#/components/schemas/Error'
        let(:scrim) { { scrim: { format: '' } } }
        run_test!
      end
    end
  end

  path '/api/v1/scrims/scrims/calendar' do
    get 'Get scrims calendar' do
      tags 'Scrims'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :year, in: :query, type: :integer, required: false
      parameter name: :month, in: :query, type: :integer, required: false

      response '200', 'calendar returned' do
        schema type: :object,
               properties: { data: { type: :array, items: { type: :object } } }
        run_test!
      end
    end
  end

  path '/api/v1/scrims/scrims/analytics' do
    get 'Get scrims analytics' do
      tags 'Scrims'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :days, in: :query, type: :integer, required: false, description: 'Lookback window in days'

      response '200', 'analytics returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     total_scrims: { type: :integer },
                     wins: { type: :integer },
                     losses: { type: :integer },
                     win_rate: { type: :number }
                   }
                 }
               }
        run_test!
      end
    end
  end

  path '/api/v1/scrims/scrims/{id}' do
    get 'Get scrim details' do
      tags 'Scrims'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'scrim found' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end

      response '404', 'scrim not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { 'nonexistent' }
        run_test!
      end
    end

    patch 'Update a scrim' do
      tags 'Scrims'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :scrim, in: :body, schema: {
        type: :object,
        properties: {
          scrim: {
            type: :object,
            properties: {
              notes: { type: :string },
              result: { type: :string, enum: %w[win loss draw pending], nullable: true }
            }
          }
        }
      }

      response '200', 'scrim updated' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        let(:scrim) { { scrim: { notes: 'Updated notes' } } }
        run_test!
      end
    end

    delete 'Delete a scrim' do
      tags 'Scrims'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'scrim deleted' do
        schema type: :object,
               properties: { message: { type: :string } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  path '/api/v1/scrims/scrims/{id}/add_game' do
    post 'Add a game result to a scrim' do
      tags 'Scrims'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :game, in: :body, schema: {
        type: :object,
        properties: {
          game: {
            type: :object,
            properties: {
              result: { type: :string, enum: %w[win loss], example: 'win' },
              duration: { type: :integer, example: 1800, description: 'Game duration in seconds' },
              side: { type: :string, enum: %w[blue red], example: 'blue' },
              notes: { type: :string, nullable: true }
            },
            required: %w[result side]
          }
        }
      }

      response '201', 'game added' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        let(:game) { { game: { result: 'win', side: 'blue' } } }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Opponent Teams
  # ---------------------------------------------------------------------------

  path '/api/v1/scrims/opponent-teams' do
    get 'List opponent teams' do
      tags 'Scrims'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :search, in: :query, type: :string, required: false

      response '200', 'opponent teams returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     opponent_teams: { type: :array, items: { type: :object } },
                     pagination: { '$ref' => '#/components/schemas/Pagination' }
                   }
                 }
               }
        run_test!
      end
    end

    post 'Create an opponent team' do
      tags 'Scrims'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :opponent_team, in: :body, schema: {
        type: :object,
        properties: {
          opponent_team: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Team Rival' },
              region: { type: :string, example: 'BR' },
              tier: { type: :string, enum: %w[amateur semi_pro professional], example: 'semi_pro' },
              notes: { type: :string, nullable: true }
            },
            required: ['name']
          }
        }
      }

      response '201', 'opponent team created' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:opponent_team) { { opponent_team: { name: 'Team Rival', region: 'BR', tier: 'semi_pro' } } }
        run_test!
      end
    end
  end

  path '/api/v1/scrims/opponent-teams/{id}' do
    get 'Get opponent team details' do
      tags 'Scrims'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'opponent team found' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end

    patch 'Update an opponent team' do
      tags 'Scrims'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :opponent_team, in: :body, schema: {
        type: :object,
        properties: {
          opponent_team: {
            type: :object,
            properties: {
              name: { type: :string },
              notes: { type: :string }
            }
          }
        }
      }

      response '200', 'opponent team updated' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        let(:opponent_team) { { opponent_team: { name: 'Updated Name' } } }
        run_test!
      end
    end

    delete 'Delete an opponent team' do
      tags 'Scrims'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'opponent team deleted' do
        schema type: :object,
               properties: { message: { type: :string } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  path '/api/v1/scrims/opponent-teams/{id}/scrim-history' do
    get 'Get scrim history with a specific opponent' do
      tags 'Scrims'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false

      response '200', 'scrim history returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     scrims: { type: :array, items: { type: :object } },
                     summary: {
                       type: :object,
                       properties: {
                         total: { type: :integer },
                         wins: { type: :integer },
                         losses: { type: :integer }
                       }
                     }
                   }
                 }
               }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end
end
