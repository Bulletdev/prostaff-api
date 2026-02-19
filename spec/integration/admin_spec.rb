# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :owner, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  # ---------------------------------------------------------------------------
  # Admin — Players
  # ---------------------------------------------------------------------------

  path '/api/v1/admin/players' do
    get 'List all players across all organizations (admin)' do
      tags 'Admin'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :include_deleted, in: :query, type: :boolean, required: false,
                description: 'Include soft-deleted players'
      parameter name: :role, in: :query, type: :string, required: false
      parameter name: :status, in: :query, type: :string, required: false
      parameter name: :has_access, in: :query, type: :boolean, required: false,
                description: 'Filter by whether player portal access is enabled'
      parameter name: :sort_by, in: :query, type: :string, required: false
      parameter name: :sort_order, in: :query, type: :string, required: false,
                description: 'asc or desc'

      response '200', 'players returned' do
        schema type: :object,
               properties: {
                 players: { type: :array, items: { '$ref' => '#/components/schemas/Player' } },
                 pagination: { '$ref' => '#/components/schemas/Pagination' },
                 summary: {
                   type: :object,
                   properties: {
                     total: { type: :integer },
                     active: { type: :integer },
                     deleted: { type: :integer },
                     with_access: { type: :integer }
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

      response '403', 'forbidden — admin/owner role required' do
        schema '$ref' => '#/components/schemas/Error'
        let(:user) { create(:user, :viewer, organization: organization) }
        run_test!
      end
    end
  end

  path '/api/v1/admin/players/{id}/soft_delete' do
    post 'Soft-delete (archive) a player' do
      tags 'Admin'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          reason: { type: :string, example: 'Player left the organization' }
        },
        required: ['reason']
      }

      response '200', 'player archived' do
        schema type: :object,
               properties: { player: { '$ref' => '#/components/schemas/Player' } }
        let(:id) { create(:player, organization: organization).id }
        let(:body) { { reason: 'Left the org' } }
        run_test!
      end

      response '404', 'player not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { 'nonexistent' }
        let(:body) { { reason: 'Left the org' } }
        run_test!
      end
    end
  end

  path '/api/v1/admin/players/{id}/restore' do
    post 'Restore an archived player' do
      tags 'Admin'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          status: {
            type: :string,
            enum: %w[active inactive benched trial],
            example: 'active'
          }
        },
        required: ['status']
      }

      response '200', 'player restored' do
        schema type: :object,
               properties: { player: { '$ref' => '#/components/schemas/Player' } }
        let(:id) { 'nonexistent' }
        let(:body) { { status: 'active' } }
        run_test!
      end
    end
  end

  path '/api/v1/admin/players/{id}/enable_access' do
    post 'Enable player portal access' do
      tags 'Admin'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email, example: 'player@team.gg' },
          password: { type: :string, format: :password, example: 'SecurePass123!' }
        },
        required: %w[email password]
      }

      response '200', 'player access enabled' do
        schema type: :object,
               properties: { player: { '$ref' => '#/components/schemas/Player' } }
        let(:id) { create(:player, organization: organization).id }
        let(:body) { { email: 'player@team.gg', password: 'SecurePass123!' } }
        run_test!
      end

      response '422', 'validation error' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { 'nonexistent' }
        let(:body) { { email: 'invalid', password: '123' } }
        run_test!
      end
    end
  end

  path '/api/v1/admin/players/{id}/disable_access' do
    post 'Disable player portal access' do
      tags 'Admin'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'player access disabled' do
        schema type: :object,
               properties: { player: { '$ref' => '#/components/schemas/Player' } }
        let(:id) { create(:player, organization: organization).id }
        run_test!
      end
    end
  end

  path '/api/v1/admin/players/{id}/change_status' do
    post 'Change the status of a non-archived player' do
      tags 'Admin'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          status: {
            type: :string,
            enum: %w[active inactive benched trial],
            example: 'benched'
          }
        },
        required: ['status']
      }

      response '200', 'player status changed' do
        schema type: :object,
               properties: {
                 message: { type: :string },
                 player: { '$ref' => '#/components/schemas/Player' }
               }
        let(:id) { create(:player, organization: organization).id }
        let(:body) { { status: 'benched' } }
        run_test!
      end

      response '422', 'invalid status or player is archived' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { 'nonexistent' }
        let(:body) { { status: 'removed' } }
        run_test!
      end
    end
  end

  path '/api/v1/admin/players/{id}/transfer' do
    post 'Transfer player to another organization' do
      tags 'Admin'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          new_organization_id: { type: :string, format: :uuid, example: 'org-uuid-here' },
          reason: { type: :string, nullable: true, example: 'Trade agreement' }
        },
        required: ['new_organization_id']
      }

      response '200', 'player transferred' do
        schema type: :object,
               properties: {
                 player: { '$ref' => '#/components/schemas/Player' },
                 previous_organization: { type: :string },
                 new_organization: { type: :string }
               }
        let(:target_org) { create(:organization) }
        let(:id) { create(:player, organization: organization).id }
        let(:body) { { new_organization_id: target_org.id, reason: 'Trade' } }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Admin — Audit Logs
  # ---------------------------------------------------------------------------

  path '/api/v1/admin/audit-logs' do
    get 'List audit logs' do
      tags 'Admin'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :action, in: :query, type: :string, required: false,
                description: 'Filter by action type (e.g. soft_delete, transfer)'
      parameter name: :entity_type, in: :query, type: :string, required: false,
                description: 'Filter by entity type (e.g. Player, Organization)'
      parameter name: :user_id, in: :query, type: :string, required: false

      response '200', 'audit logs returned' do
        schema type: :object,
               properties: {
                 logs: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       user: { type: :object },
                       organization: { type: :object },
                       action: { type: :string },
                       entity_type: { type: :string },
                       entity_id: { type: :string },
                       old_values: { type: :object, nullable: true },
                       new_values: { type: :object, nullable: true },
                       created_at: { type: :string, format: 'date-time' }
                     }
                   }
                 },
                 pagination: { '$ref' => '#/components/schemas/Pagination' }
               }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Admin — Organizations
  # ---------------------------------------------------------------------------

  path '/api/v1/admin/organizations' do
    get 'List all organizations (admin)' do
      tags 'Admin'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :search, in: :query, type: :string, required: false
      parameter name: :tier, in: :query, type: :string, required: false
      parameter name: :status, in: :query, type: :string, required: false

      response '200', 'organizations returned' do
        schema type: :object,
               properties: {
                 organizations: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       name: { type: :string },
                       slug: { type: :string },
                       region: { type: :string },
                       tier: { type: :string },
                       subscription_plan: { type: :string },
                       subscription_status: { type: :string },
                       users_count: { type: :integer },
                       created_at: { type: :string, format: 'date-time' }
                     }
                   }
                 },
                 pagination: { '$ref' => '#/components/schemas/Pagination' }
               }
        run_test!
      end
    end
  end
end
