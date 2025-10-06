require 'swagger_helper'

RSpec.describe 'Authentication API', type: :request do
  path '/api/v1/auth/register' do
    post 'Register new organization and admin user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :registration, in: :body, schema: {
        type: :object,
        properties: {
          organization: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Team Alpha' },
              region: { type: :string, example: 'BR' },
              tier: { type: :string, enum: ['amateur', 'semi_pro', 'professional'], example: 'semi_pro' }
            },
            required: ['name', 'region', 'tier']
          },
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email, example: 'admin@teamalpha.gg' },
              password: { type: :string, format: :password, example: 'password123' },
              full_name: { type: :string, example: 'John Doe' },
              timezone: { type: :string, example: 'America/Sao_Paulo' },
              language: { type: :string, example: 'pt-BR' }
            },
            required: ['email', 'password', 'full_name']
          }
        },
        required: ['organization', 'user']
      }

      response '201', 'registration successful' do
        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                user: { '$ref' => '#/components/schemas/User' },
                organization: { '$ref' => '#/components/schemas/Organization' },
                access_token: { type: :string },
                refresh_token: { type: :string },
                expires_in: { type: :integer }
              }
            }
          }

        let(:registration) do
          {
            organization: {
              name: 'Team Alpha',
              region: 'BR',
              tier: 'semi_pro'
            },
            user: {
              email: 'admin@teamalpha.gg',
              password: 'password123',
              full_name: 'John Doe',
              timezone: 'America/Sao_Paulo',
              language: 'pt-BR'
            }
          }
        end

        run_test!
      end

      response '422', 'validation errors' do
        schema '$ref' => '#/components/schemas/Error'

        let(:registration) do
          {
            organization: { name: '', region: '', tier: '' },
            user: { email: 'invalid', password: '123' }
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/auth/login' do
    post 'Login user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email, example: 'admin@teamalpha.gg' },
          password: { type: :string, format: :password, example: 'password123' }
        },
        required: ['email', 'password']
      }

      response '200', 'login successful' do
        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                user: { '$ref' => '#/components/schemas/User' },
                organization: { '$ref' => '#/components/schemas/Organization' },
                access_token: { type: :string },
                refresh_token: { type: :string },
                expires_in: { type: :integer }
              }
            }
          }

        let(:credentials) { { email: user.email, password: 'password123' } }
        let(:organization) { create(:organization) }
        let(:user) { create(:user, organization: organization, password: 'password123') }

        run_test!
      end

      response '401', 'invalid credentials' do
        schema '$ref' => '#/components/schemas/Error'

        let(:credentials) { { email: 'wrong@email.com', password: 'wrong' } }

        run_test!
      end
    end
  end

  path '/api/v1/auth/refresh' do
    post 'Refresh access token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :refresh, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string, example: 'eyJhbGciOiJIUzI1NiJ9...' }
        },
        required: ['refresh_token']
      }

      response '200', 'token refreshed successfully' do
        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                access_token: { type: :string },
                refresh_token: { type: :string },
                expires_in: { type: :integer }
              }
            }
          }

        let(:organization) { create(:organization) }
        let(:user) { create(:user, organization: organization) }
        let(:tokens) { Authentication::Services::JwtService.generate_tokens(user) }
        let(:refresh) { { refresh_token: tokens[:refresh_token] } }

        run_test!
      end

      response '401', 'invalid refresh token' do
        schema '$ref' => '#/components/schemas/Error'

        let(:refresh) { { refresh_token: 'invalid_token' } }

        run_test!
      end
    end
  end

  path '/api/v1/auth/me' do
    get 'Get current user info' do
      tags 'Authentication'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'user info retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                user: { '$ref' => '#/components/schemas/User' },
                organization: { '$ref' => '#/components/schemas/Organization' }
              }
            }
          }

        let(:organization) { create(:organization) }
        let(:user) { create(:user, organization: organization) }
        let(:Authorization) { "Bearer #{Authentication::Services::JwtService.generate_tokens(user)[:access_token]}" }

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/Error'

        let(:Authorization) { 'Bearer invalid_token' }

        run_test!
      end
    end
  end

  path '/api/v1/auth/logout' do
    post 'Logout user' do
      tags 'Authentication'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'logout successful' do
        schema type: :object,
          properties: {
            message: { type: :string },
            data: { type: :object }
          }

        let(:organization) { create(:organization) }
        let(:user) { create(:user, organization: organization) }
        let(:Authorization) { "Bearer #{Authentication::Services::JwtService.generate_tokens(user)[:access_token]}" }

        run_test!
      end
    end
  end

  path '/api/v1/auth/forgot-password' do
    post 'Request password reset' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :email_params, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email, example: 'user@example.com' }
        },
        required: ['email']
      }

      response '200', 'password reset email sent' do
        schema type: :object,
          properties: {
            message: { type: :string },
            data: { type: :object }
          }

        let(:organization) { create(:organization) }
        let(:user) { create(:user, organization: organization) }
        let(:email_params) { { email: user.email } }

        run_test!
      end
    end
  end

  path '/api/v1/auth/reset-password' do
    post 'Reset password with token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :reset_params, in: :body, schema: {
        type: :object,
        properties: {
          token: { type: :string, example: 'reset_token_here' },
          password: { type: :string, format: :password, example: 'newpassword123' },
          password_confirmation: { type: :string, format: :password, example: 'newpassword123' }
        },
        required: ['token', 'password', 'password_confirmation']
      }

      response '200', 'password reset successful' do
        schema type: :object,
          properties: {
            message: { type: :string },
            data: { type: :object }
          }

        let(:organization) { create(:organization) }
        let(:user) { create(:user, organization: organization) }
        let(:reset_token) do
          payload = {
            user_id: user.id,
            type: 'password_reset',
            exp: 1.hour.from_now.to_i,
            iat: Time.current.to_i
          }
          JWT.encode(payload, Authentication::Services::JwtService::SECRET_KEY, 'HS256')
        end
        let(:reset_params) do
          {
            token: reset_token,
            password: 'newpassword123',
            password_confirmation: 'newpassword123'
          }
        end

        run_test!
      end

      response '400', 'invalid or expired token' do
        schema '$ref' => '#/components/schemas/Error'

        let(:reset_params) do
          {
            token: 'invalid_token',
            password: 'newpassword123',
            password_confirmation: 'newpassword123'
          }
        end

        run_test!
      end
    end
  end
end
