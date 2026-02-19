# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Team Members API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  # ---------------------------------------------------------------------------
  # Team Members
  # ---------------------------------------------------------------------------

  path '/api/v1/team-members' do
    get 'List all team members (staff) for the organization' do
      tags 'Team Members'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :role, in: :query, type: :string, required: false,
                description: 'Filter by role: owner, admin, coach, analyst, viewer'

      response '200', 'team members returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     team_members: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :string },
                           name: { type: :string },
                           email: { type: :string },
                           role: { type: :string },
                           avatar_url: { type: :string, nullable: true },
                           created_at: { type: :string, format: 'date-time' }
                         }
                       }
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
  end
end
