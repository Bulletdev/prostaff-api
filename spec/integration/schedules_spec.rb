require 'swagger_helper'

RSpec.describe 'Schedules API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  path '/api/v1/schedules' do
    get 'List all schedules' do
      tags 'Schedules'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'
      parameter name: :event_type, in: :query, type: :string, required: false, description: 'Filter by event type (match, scrim, practice, meeting, other)'
      parameter name: :status, in: :query, type: :string, required: false, description: 'Filter by status (scheduled, ongoing, completed, cancelled)'
      parameter name: :start_date, in: :query, type: :string, required: false, description: 'Start date for filtering (YYYY-MM-DD)'
      parameter name: :end_date, in: :query, type: :string, required: false, description: 'End date for filtering (YYYY-MM-DD)'
      parameter name: :upcoming, in: :query, type: :boolean, required: false, description: 'Filter upcoming events'
      parameter name: :past, in: :query, type: :boolean, required: false, description: 'Filter past events'
      parameter name: :today, in: :query, type: :boolean, required: false, description: 'Filter today\'s events'
      parameter name: :this_week, in: :query, type: :boolean, required: false, description: 'Filter this week\'s events'
      parameter name: :sort_order, in: :query, type: :string, required: false, description: 'Sort order (asc, desc)'

      response '200', 'schedules found' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                schedules: {
                  type: :array,
                  items: { '$ref' => '#/components/schemas/Schedule' }
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

    post 'Create a schedule' do
      tags 'Schedules'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :schedule, in: :body, schema: {
        type: :object,
        properties: {
          schedule: {
            type: :object,
            properties: {
              event_type: { type: :string, enum: %w[match scrim practice meeting other] },
              title: { type: :string },
              description: { type: :string },
              start_time: { type: :string, format: 'date-time' },
              end_time: { type: :string, format: 'date-time' },
              location: { type: :string },
              opponent_name: { type: :string },
              status: { type: :string, enum: %w[scheduled ongoing completed cancelled], default: 'scheduled' },
              match_id: { type: :string },
              meeting_url: { type: :string },
              all_day: { type: :boolean },
              timezone: { type: :string },
              color: { type: :string },
              is_recurring: { type: :boolean },
              recurrence_rule: { type: :string },
              recurrence_end_date: { type: :string, format: 'date' },
              reminder_minutes: { type: :integer },
              required_players: { type: :array, items: { type: :string } },
              optional_players: { type: :array, items: { type: :string } },
              tags: { type: :array, items: { type: :string } }
            },
            required: %w[event_type title start_time end_time]
          }
        }
      }

      response '201', 'schedule created' do
        let(:schedule) do
          {
            schedule: {
              event_type: 'scrim',
              title: 'Scrim vs Team X',
              start_time: 2.days.from_now.iso8601,
              end_time: 2.days.from_now.advance(hours: 2).iso8601,
              status: 'scheduled'
            }
          }
        end

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                schedule: { '$ref' => '#/components/schemas/Schedule' }
              }
            }
          }

        run_test!
      end

      response '422', 'invalid request' do
        let(:schedule) { { schedule: { event_type: 'invalid' } } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/schedules/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Schedule ID'

    get 'Show schedule details' do
      tags 'Schedules'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'schedule found' do
        let(:id) { create(:schedule, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                schedule: { '$ref' => '#/components/schemas/Schedule' }
              }
            }
          }

        run_test!
      end

      response '404', 'schedule not found' do
        let(:id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    patch 'Update a schedule' do
      tags 'Schedules'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :schedule, in: :body, schema: {
        type: :object,
        properties: {
          schedule: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              status: { type: :string },
              location: { type: :string },
              meeting_url: { type: :string }
            }
          }
        }
      }

      response '200', 'schedule updated' do
        let(:id) { create(:schedule, organization: organization).id }
        let(:schedule) { { schedule: { title: 'Updated Title' } } }

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                schedule: { '$ref' => '#/components/schemas/Schedule' }
              }
            }
          }

        run_test!
      end
    end

    delete 'Delete a schedule' do
      tags 'Schedules'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'schedule deleted' do
        let(:id) { create(:schedule, organization: organization).id }

        schema type: :object,
          properties: {
            message: { type: :string }
          }

        run_test!
      end
    end
  end
end
