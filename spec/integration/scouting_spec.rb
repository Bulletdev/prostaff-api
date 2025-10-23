# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Scouting API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  path '/api/v1/scouting/players' do
    get 'List all scouting targets' do
      tags 'Scouting'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'
      parameter name: :role, in: :query, type: :string, required: false,
                description: 'Filter by role (top, jungle, mid, adc, support)'
      parameter name: :status, in: :query, type: :string, required: false,
                description: 'Filter by status (watching, contacted, negotiating, rejected, signed)'
      parameter name: :priority, in: :query, type: :string, required: false,
                description: 'Filter by priority (low, medium, high, critical)'
      parameter name: :region, in: :query, type: :string, required: false, description: 'Filter by region'
      parameter name: :active, in: :query, type: :boolean, required: false, description: 'Filter active targets only'
      parameter name: :high_priority, in: :query, type: :boolean, required: false,
                description: 'Filter high priority targets only'
      parameter name: :needs_review, in: :query, type: :boolean, required: false,
                description: 'Filter targets needing review'
      parameter name: :assigned_to_id, in: :query, type: :string, required: false,
                description: 'Filter by assigned user'
      parameter name: :search, in: :query, type: :string, required: false,
                description: 'Search by summoner name or real name'
      parameter name: :sort_by, in: :query, type: :string, required: false, description: 'Sort field'
      parameter name: :sort_order, in: :query, type: :string, required: false, description: 'Sort order (asc, desc)'

      response '200', 'scouting targets found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     players: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/ScoutingTarget' }
                     },
                     total: { type: :integer },
                     page: { type: :integer },
                     per_page: { type: :integer },
                     total_pages: { type: :integer }
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

    post 'Create a scouting target' do
      tags 'Scouting'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :scouting_target, in: :body, schema: {
        type: :object,
        properties: {
          scouting_target: {
            type: :object,
            properties: {
              summoner_name: { type: :string },
              real_name: { type: :string },
              role: { type: :string, enum: %w[top jungle mid adc support] },
              region: { type: :string, enum: %w[BR NA EUW KR EUNE LAN LAS OCE RU TR JP] },
              nationality: { type: :string },
              age: { type: :integer },
              status: { type: :string, enum: %w[watching contacted negotiating rejected signed], default: 'watching' },
              priority: { type: :string, enum: %w[low medium high critical], default: 'medium' },
              current_team: { type: :string },
              email: { type: :string, format: :email },
              phone: { type: :string },
              discord_username: { type: :string },
              twitter_handle: { type: :string },
              scouting_notes: { type: :string },
              contact_notes: { type: :string },
              availability: { type: :string },
              salary_expectations: { type: :string },
              assigned_to_id: { type: :string }
            },
            required: %w[summoner_name region role]
          }
        }
      }

      response '201', 'scouting target created' do
        let(:scouting_target) do
          {
            scouting_target: {
              summoner_name: 'ProPlayer123',
              real_name: 'João Silva',
              role: 'mid',
              region: 'BR',
              priority: 'high',
              status: 'watching'
            }
          }
        end

        schema type: :object,
               properties: {
                 message: { type: :string },
                 data: {
                   type: :object,
                   properties: {
                     scouting_target: { '$ref' => '#/components/schemas/ScoutingTarget' }
                   }
                 }
               }

        run_test!
      end

      response '422', 'invalid request' do
        let(:scouting_target) { { scouting_target: { summoner_name: '' } } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/scouting/players/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Scouting Target ID'

    get 'Show scouting target details' do
      tags 'Scouting'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'scouting target found' do
        let(:id) { create(:scouting_target, organization: organization).id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     scouting_target: { '$ref' => '#/components/schemas/ScoutingTarget' }
                   }
                 }
               }

        run_test!
      end

      response '404', 'scouting target not found' do
        let(:id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    patch 'Update a scouting target' do
      tags 'Scouting'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :scouting_target, in: :body, schema: {
        type: :object,
        properties: {
          scouting_target: {
            type: :object,
            properties: {
              status: { type: :string },
              priority: { type: :string },
              scouting_notes: { type: :string },
              contact_notes: { type: :string }
            }
          }
        }
      }

      response '200', 'scouting target updated' do
        let(:id) { create(:scouting_target, organization: organization).id }
        let(:scouting_target) { { scouting_target: { status: 'contacted', priority: 'critical' } } }

        schema type: :object,
               properties: {
                 message: { type: :string },
                 data: {
                   type: :object,
                   properties: {
                     scouting_target: { '$ref' => '#/components/schemas/ScoutingTarget' }
                   }
                 }
               }

        run_test!
      end
    end

    delete 'Delete a scouting target' do
      tags 'Scouting'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'scouting target deleted' do
        let(:user) { create(:user, :owner, organization: organization) }
        let(:id) { create(:scouting_target, organization: organization).id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               }

        run_test!
      end
    end
  end

  path '/api/v1/scouting/regions' do
    get 'Get scouting statistics by region' do
      tags 'Scouting'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'regional statistics retrieved' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     regions: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           region: { type: :string },
                           total_targets: { type: :integer },
                           by_status: { type: :object },
                           by_priority: { type: :object },
                           avg_tier: { type: :string }
                         }
                       }
                     }
                   }
                 }
               }

        run_test!
      end
    end
  end

  path '/api/v1/scouting/watchlist' do
    get 'Get watchlist (active scouting targets)' do
      tags 'Scouting'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :assigned_to_me, in: :query, type: :boolean, required: false,
                description: 'Filter targets assigned to current user'

      response '200', 'watchlist retrieved' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     watchlist: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/ScoutingTarget' }
                     },
                     stats: {
                       type: :object,
                       properties: {
                         total: { type: :integer },
                         needs_review: { type: :integer },
                         high_priority: { type: :integer }
                       }
                     }
                   }
                 }
               }

        run_test!
      end
    end
  end
end
