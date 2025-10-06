require 'swagger_helper'

RSpec.describe 'Dashboard API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.generate_tokens(user)[:access_token]}" }

  path '/api/v1/dashboard' do
    get 'Get dashboard overview' do
      tags 'Dashboard'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'dashboard data retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                stats: {
                  type: :object,
                  properties: {
                    total_players: { type: :integer },
                    active_players: { type: :integer },
                    total_matches: { type: :integer },
                    wins: { type: :integer },
                    losses: { type: :integer },
                    win_rate: { type: :number, format: :float },
                    recent_form: { type: :string, example: 'WWLWW' },
                    avg_kda: { type: :number, format: :float },
                    active_goals: { type: :integer },
                    completed_goals: { type: :integer },
                    upcoming_matches: { type: :integer }
                  }
                },
                recent_matches: {
                  type: :array,
                  items: { '$ref' => '#/components/schemas/Match' }
                },
                upcoming_events: { type: :array },
                active_goals: { type: :array },
                roster_status: {
                  type: :object,
                  properties: {
                    by_role: { type: :object },
                    by_status: { type: :object },
                    contracts_expiring: { type: :integer }
                  }
                }
              }
            }
          }

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/Error'

        let(:Authorization) { 'Bearer invalid_token' }

        run_test!
      end
    end
  end

  path '/api/v1/dashboard/stats' do
    get 'Get dashboard statistics' do
      tags 'Dashboard'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'stats retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                total_players: { type: :integer },
                active_players: { type: :integer },
                total_matches: { type: :integer },
                wins: { type: :integer },
                losses: { type: :integer },
                win_rate: { type: :number, format: :float },
                recent_form: { type: :string, example: 'WWLWW' },
                avg_kda: { type: :number, format: :float },
                active_goals: { type: :integer },
                completed_goals: { type: :integer },
                upcoming_matches: { type: :integer }
              }
            }
          }

        run_test!
      end
    end
  end

  path '/api/v1/dashboard/activities' do
    get 'Get recent activities' do
      tags 'Dashboard'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'activities retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                activities: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {
                      id: { type: :string, format: :uuid },
                      action: { type: :string },
                      entity_type: { type: :string },
                      entity_id: { type: :string, format: :uuid },
                      user: { type: :string },
                      timestamp: { type: :string, format: 'date-time' },
                      changes: { type: :object, nullable: true }
                    }
                  }
                },
                count: { type: :integer }
              }
            }
          }

        run_test!
      end
    end
  end

  path '/api/v1/dashboard/schedule' do
    get 'Get upcoming schedule' do
      tags 'Dashboard'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'schedule retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                events: { type: :array },
                count: { type: :integer }
              }
            }
          }

        run_test!
      end
    end
  end
end
