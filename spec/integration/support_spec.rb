# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Support API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{JwtService.encode({ user_id: user.id })}" }

  # ---------------------------------------------------------------------------
  # Tickets
  # ---------------------------------------------------------------------------

  path '/api/v1/support/tickets' do
    get "List user's support tickets" do
      tags 'Support'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :status, in: :query, type: :string, required: false,
                description: 'Filter by status: open, in_progress, resolved, closed'

      response '200', 'tickets returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     tickets: { type: :array, items: { type: :object } },
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

    post 'Create a support ticket' do
      tags 'Support'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :ticket, in: :body, schema: {
        type: :object,
        properties: {
          ticket: {
            type: :object,
            properties: {
              subject: { type: :string, example: 'Cannot import matches from Riot API' },
              description: { type: :string, example: 'When I try to import matches, I get a 500 error.' },
              category: { type: :string, enum: %w[technical feature_request billing riot_integration other], example: 'technical' },
              priority: { type: :string, enum: %w[low medium high urgent], example: 'high' }
            },
            required: %w[subject description category]
          }
        }
      }

      response '201', 'ticket created' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:ticket) do
          {
            ticket: {
              subject: 'Cannot import matches',
              description: 'Getting 500 error on import when using the Riot integration.',
              category: 'riot_integration',
              priority: 'high'
            }
          }
        end
        run_test!
      end

      response '422', 'validation error' do
        schema type: :object, properties: { error: { type: :object } }
        let(:ticket) { { ticket: { subject: '' } } }
        run_test!
      end
    end
  end

  path '/api/v1/support/tickets/{id}' do
    get 'Get support ticket details' do
      tags 'Support'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'ticket found' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { create(:support_ticket, organization: organization, user: user).id }
        run_test!
      end

      response '404', 'ticket not found' do
        schema type: :object, properties: { error: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end
    end

    patch 'Update a support ticket' do
      tags 'Support'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :ticket, in: :body, schema: {
        type: :object,
        properties: {
          ticket: {
            type: :object,
            properties: {
              description: { type: :string },
              priority: { type: :string, enum: %w[low medium high urgent] }
            }
          }
        }
      }

      response '200', 'ticket updated' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { create(:support_ticket, organization: organization, user: user).id }
        let(:ticket) { { ticket: { priority: 'medium' } } }
        run_test!
      end
    end
  end

  path '/api/v1/support/tickets/{id}/close' do
    post 'Close a support ticket' do
      tags 'Support'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'ticket closed' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { create(:support_ticket, organization: organization, user: user).id }
        run_test!
      end
    end
  end

  path '/api/v1/support/tickets/{id}/reopen' do
    post 'Reopen a closed support ticket' do
      tags 'Support'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'ticket reopened' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { create(:support_ticket, :resolved, organization: organization, user: user).id }
        run_test!
      end
    end
  end

  path '/api/v1/support/tickets/{id}/messages' do
    post 'Add a message to a support ticket' do
      tags 'Support'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :message, in: :body, schema: {
        type: :object,
        properties: {
          message: {
            type: :object,
            properties: {
              content: { type: :string, example: 'Here is additional context about the issue.' }
            },
            required: ['content']
          }
        }
      }

      response '201', 'message added' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { create(:support_ticket, organization: organization, user: user).id }
        let(:message) { { message: { content: 'Additional context about the issue.' } } }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # FAQ
  # ---------------------------------------------------------------------------

  path '/api/v1/support/faq' do
    get 'List all FAQs' do
      tags 'Support'
      produces 'application/json'

      parameter name: :category, in: :query, type: :string, required: false
      parameter name: :search, in: :query, type: :string, required: false

      response '200', 'FAQs returned' do
        schema type: :object,
               properties: { data: { type: :object } }
        run_test!
      end
    end
  end

  path '/api/v1/support/faq/{slug}' do
    get 'Get a FAQ by slug' do
      tags 'Support'
      produces 'application/json'

      parameter name: :slug, in: :path, type: :string, required: true

      response '200', 'FAQ found' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:slug) { create(:support_faq).slug }
        run_test!
      end

      response '404', 'FAQ not found' do
        schema type: :object, properties: { error: { type: :object } }
        let(:slug) { 'nonexistent-faq' }
        run_test!
      end
    end
  end

  path '/api/v1/support/faq/{slug}/helpful' do
    post 'Mark a FAQ as helpful' do
      tags 'Support'
      produces 'application/json'

      parameter name: :slug, in: :path, type: :string, required: true

      response '200', 'FAQ marked as helpful' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:slug) { create(:support_faq).slug }
        run_test!
      end
    end
  end

  path '/api/v1/support/faq/{slug}/not-helpful' do
    post 'Mark a FAQ as not helpful' do
      tags 'Support'
      produces 'application/json'

      parameter name: :slug, in: :path, type: :string, required: true

      response '200', 'FAQ marked as not helpful' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:slug) { create(:support_faq).slug }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Staff Endpoints
  # ---------------------------------------------------------------------------

  path '/api/v1/support/staff/dashboard' do
    get 'Support staff dashboard' do
      tags 'Support — Staff'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'staff dashboard returned' do
        schema type: :object,
               properties: { data: { type: :object } }
        run_test!
      end

      response '401', 'unauthorized — staff role required' do
        schema '$ref' => '#/components/schemas/Error'
        let(:user) { create(:user, :viewer, organization: organization) }
        run_test!
      end
    end
  end

  path '/api/v1/support/staff/analytics' do
    get 'Support analytics for staff' do
      tags 'Support — Staff'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :start_date, in: :query, type: :string, required: false
      parameter name: :end_date, in: :query, type: :string, required: false

      response '200', 'support analytics returned' do
        schema type: :object,
               properties: { data: { type: :object } }
        run_test!
      end
    end
  end

  path '/api/v1/support/staff/tickets/{id}/assign' do
    post 'Assign a ticket to a staff member' do
      tags 'Support — Staff'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          assigned_to_id: { type: :string, format: :uuid }
        },
        required: ['assigned_to_id']
      }

      response '200', 'ticket assigned' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:ticket) { create(:support_ticket, organization: organization, user: user) }
        let(:id) { ticket.id }
        let(:body) { { assigned_to_id: user.id } }
        run_test!
      end
    end
  end

  path '/api/v1/support/staff/tickets/{id}/resolve' do
    post 'Resolve a ticket' do
      tags 'Support — Staff'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          resolution_note: { type: :string, example: 'Resolved by updating the API key.' }
        }
      }

      response '200', 'ticket resolved' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { create(:support_ticket, organization: organization, user: user).id }
        let(:body) { { resolution_note: 'Fixed.' } }
        run_test!
      end
    end
  end
end
