# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Constants API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  path '/api/v1/constants' do
    get 'Get application constants and enumerations' do
      tags 'Constants'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'constants returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     player_statuses: {
                       type: :array,
                       items: { type: :string },
                       example: %w[active inactive benched trial]
                     },
                     player_roles: {
                       type: :array,
                       items: { type: :string },
                       example: %w[top jungle mid adc support]
                     },
                     scrim_formats: {
                       type: :array,
                       items: { type: :string },
                       example: %w[bo1 bo3 bo5]
                     },
                     user_roles: {
                       type: :array,
                       items: { type: :string },
                       example: %w[owner admin coach analyst viewer]
                     },
                     regions: {
                       type: :array,
                       items: { type: :string }
                     },
                     ticket_categories: {
                       type: :array,
                       items: { type: :string },
                       example: %w[bug feature_request billing other]
                     },
                     ticket_priorities: {
                       type: :array,
                       items: { type: :string },
                       example: %w[low medium high urgent]
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
  end
end
