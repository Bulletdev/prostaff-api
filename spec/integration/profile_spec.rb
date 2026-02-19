# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Profile API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  # ---------------------------------------------------------------------------
  # Profile
  # ---------------------------------------------------------------------------

  path '/api/v1/profile' do
    get 'Get current user profile' do
      tags 'Profile'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'profile returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     name: { type: :string },
                     email: { type: :string },
                     role: { type: :string },
                     avatar_url: { type: :string, nullable: true },
                     organization: { '$ref' => '#/components/schemas/Organization' },
                     notification_preferences: { type: :object, nullable: true },
                     created_at: { type: :string, format: 'date-time' }
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

    patch 'Update current user profile' do
      tags 'Profile'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :profile, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              name: { type: :string, example: 'John Doe' },
              email: { type: :string, format: :email, example: 'john@team.gg' },
              avatar_url: { type: :string, nullable: true }
            }
          }
        }
      }

      response '200', 'profile updated' do
        schema type: :object,
               properties: { data: { '$ref' => '#/components/schemas/User' } }
        let(:profile) { { user: { name: 'Updated Name' } } }
        run_test!
      end

      response '422', 'validation error' do
        schema '$ref' => '#/components/schemas/Error'
        let(:profile) { { user: { email: 'invalid-email' } } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        schema '$ref' => '#/components/schemas/Error'
        let(:profile) { {} }
        run_test!
      end
    end
  end

  path '/api/v1/profile/password' do
    patch 'Change current user password' do
      tags 'Profile'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          current_password: { type: :string, format: :password, example: 'OldPass123!' },
          password: { type: :string, format: :password, example: 'NewPass456!' },
          password_confirmation: { type: :string, format: :password, example: 'NewPass456!' }
        },
        required: %w[current_password password password_confirmation]
      }

      response '200', 'password changed' do
        schema type: :object,
               properties: { message: { type: :string } }
        let(:body) do
          {
            current_password: 'CurrentPass!',
            password: 'NewSecurePass!',
            password_confirmation: 'NewSecurePass!'
          }
        end
        run_test!
      end

      response '422', 'validation error — wrong current password or mismatch' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) do
          {
            current_password: 'wrong',
            password: 'New!',
            password_confirmation: 'Different!'
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/profile/notifications' do
    patch 'Update notification preferences' do
      tags 'Profile'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          notification_preferences: {
            type: :object,
            properties: {
              email_match_results: { type: :boolean, example: true },
              email_scrim_reminders: { type: :boolean, example: true },
              email_player_updates: { type: :boolean, example: false },
              push_match_results: { type: :boolean, example: true },
              push_scrim_reminders: { type: :boolean, example: true }
            }
          }
        }
      }

      response '200', 'notification preferences updated' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:body) do
          {
            notification_preferences: {
              email_match_results: true,
              email_scrim_reminders: false
            }
          }
        end
        run_test!
      end

      response '422', 'validation error' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) { { notification_preferences: nil } }
        run_test!
      end
    end
  end
end
