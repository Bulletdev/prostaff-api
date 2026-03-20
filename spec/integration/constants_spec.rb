# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Constants API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{JwtService.encode({ user_id: user.id })}" }

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
                     regions: { type: :object },
                     organization: { type: :object },
                     user: { type: :object },
                     player: { type: :object },
                     match: { type: :object }
                   }
                 }
               }
        run_test!
      end

      # Public endpoint — no authentication required
    end
  end
end
