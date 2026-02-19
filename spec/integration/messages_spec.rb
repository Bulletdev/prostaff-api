# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Messages API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  # ---------------------------------------------------------------------------
  # Messages
  # ---------------------------------------------------------------------------

  path '/api/v1/messages' do
    get 'List messages for the current user' do
      tags 'Messages'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'messages returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     messages: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :string },
                           subject: { type: :string },
                           body: { type: :string },
                           sender: { type: :object },
                           read: { type: :boolean },
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

  path '/api/v1/messages/{id}' do
    delete 'Delete a message' do
      tags 'Messages'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'message deleted' do
        schema type: :object,
               properties: { message: { type: :string } }
        let(:id) { 'nonexistent' }
        run_test!
      end

      response '404', 'message not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end
end
