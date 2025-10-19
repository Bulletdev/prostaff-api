require 'swagger_helper'

RSpec.describe 'Team Goals API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  path '/api/v1/team-goals' do
    get 'List all team goals' do
      tags 'Team Goals'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'
      parameter name: :status, in: :query, type: :string, required: false, description: 'Filter by status (not_started, in_progress, completed, cancelled)'
      parameter name: :category, in: :query, type: :string, required: false, description: 'Filter by category (performance, training, tournament, development, team_building, other)'
      parameter name: :player_id, in: :query, type: :string, required: false, description: 'Filter by player ID'
      parameter name: :type, in: :query, type: :string, required: false, description: 'Filter by type (team, player)'
      parameter name: :active, in: :query, type: :boolean, required: false, description: 'Filter active goals only'
      parameter name: :overdue, in: :query, type: :boolean, required: false, description: 'Filter overdue goals only'
      parameter name: :expiring_soon, in: :query, type: :boolean, required: false, description: 'Filter goals expiring soon'
      parameter name: :expiring_days, in: :query, type: :integer, required: false, description: 'Days threshold for expiring soon (default: 7)'
      parameter name: :assigned_to_id, in: :query, type: :string, required: false, description: 'Filter by assigned user ID'
      parameter name: :sort_by, in: :query, type: :string, required: false, description: 'Sort field (created_at, updated_at, title, status, category, start_date, end_date, progress)'
      parameter name: :sort_order, in: :query, type: :string, required: false, description: 'Sort order (asc, desc)'

      response '200', 'team goals found' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                goals: {
                  type: :array,
                  items: { '$ref' => '#/components/schemas/TeamGoal' }
                },
                pagination: { '$ref' => '#/components/schemas/Pagination' },
                summary: {
                  type: :object,
                  properties: {
                    total: { type: :integer },
                    by_status: { type: :object },
                    by_category: { type: :object },
                    active_count: { type: :integer },
                    completed_count: { type: :integer },
                    overdue_count: { type: :integer },
                    avg_progress: { type: :number, format: :float }
                  }
                }
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

    post 'Create a team goal' do
      tags 'Team Goals'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :team_goal, in: :body, schema: {
        type: :object,
        properties: {
          team_goal: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              category: { type: :string, enum: %w[performance training tournament development team_building other] },
              metric_type: { type: :string, enum: %w[percentage number kda win_rate rank other] },
              target_value: { type: :number, format: :float },
              current_value: { type: :number, format: :float },
              start_date: { type: :string, format: 'date' },
              end_date: { type: :string, format: 'date' },
              status: { type: :string, enum: %w[not_started in_progress completed cancelled], default: 'not_started' },
              progress: { type: :integer, description: 'Progress percentage (0-100)' },
              notes: { type: :string },
              player_id: { type: :string, description: 'Player ID if this is a player-specific goal' },
              assigned_to_id: { type: :string, description: 'User ID responsible for tracking this goal' }
            },
            required: %w[title category metric_type target_value start_date end_date]
          }
        }
      }

      response '201', 'team goal created' do
        let(:team_goal) do
          {
            team_goal: {
              title: 'Improve team KDA to 3.0',
              description: 'Focus on reducing deaths and improving team coordination',
              category: 'performance',
              metric_type: 'kda',
              target_value: 3.0,
              current_value: 2.5,
              start_date: Date.current.iso8601,
              end_date: 1.month.from_now.to_date.iso8601,
              status: 'in_progress',
              progress: 50
            }
          }
        end

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                goal: { '$ref' => '#/components/schemas/TeamGoal' }
              }
            }
          }

        run_test!
      end

      response '422', 'invalid request' do
        let(:team_goal) { { team_goal: { title: '' } } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/team-goals/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Team Goal ID'

    get 'Show team goal details' do
      tags 'Team Goals'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'team goal found' do
        let(:id) { create(:team_goal, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                goal: { '$ref' => '#/components/schemas/TeamGoal' }
              }
            }
          }

        run_test!
      end

      response '404', 'team goal not found' do
        let(:id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    patch 'Update a team goal' do
      tags 'Team Goals'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :team_goal, in: :body, schema: {
        type: :object,
        properties: {
          team_goal: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              status: { type: :string },
              current_value: { type: :number, format: :float },
              progress: { type: :integer },
              notes: { type: :string }
            }
          }
        }
      }

      response '200', 'team goal updated' do
        let(:id) { create(:team_goal, organization: organization).id }
        let(:team_goal) { { team_goal: { progress: 75, status: 'in_progress' } } }

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                goal: { '$ref' => '#/components/schemas/TeamGoal' }
              }
            }
          }

        run_test!
      end
    end

    delete 'Delete a team goal' do
      tags 'Team Goals'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'team goal deleted' do
        let(:id) { create(:team_goal, organization: organization).id }

        schema type: :object,
          properties: {
            message: { type: :string }
          }

        run_test!
      end
    end
  end
end
