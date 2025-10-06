require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  config.swagger_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents
  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'ProStaff API V1',
        version: 'v1',
        description: 'API documentation for ProStaff - Esports Team Management Platform',
        contact: {
          name: 'ProStaff Support',
          email: 'support@prostaff.gg'
        }
      },
      servers: [
        {
          url: 'http://localhost:3333',
          description: 'Development server'
        },
        {
          url: 'https://api.prostaff.gg',
          description: 'Production server'
        }
      ],
      paths: {},
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT',
            description: 'JWT authorization token'
          }
        },
        schemas: {
          Error: {
            type: :object,
            properties: {
              error: {
                type: :object,
                properties: {
                  code: { type: :string },
                  message: { type: :string },
                  details: { type: :object }
                },
                required: %w[code message]
              }
            },
            required: ['error']
          },
          User: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              email: { type: :string, format: :email },
              full_name: { type: :string },
              role: { type: :string, enum: %w[owner admin coach analyst viewer] },
              timezone: { type: :string },
              language: { type: :string },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: %w[id email full_name role]
          },
          Organization: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              name: { type: :string },
              region: { type: :string },
              tier: { type: :string, enum: %w[amateur semi_pro professional] },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: %w[id name region tier]
          },
          Player: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              summoner_name: { type: :string },
              real_name: { type: :string, nullable: true },
              role: { type: :string, enum: %w[top jungle mid adc support] },
              status: { type: :string, enum: %w[active inactive benched trial] },
              jersey_number: { type: :integer, nullable: true },
              country: { type: :string, nullable: true },
              solo_queue_tier: { type: :string, nullable: true },
              solo_queue_rank: { type: :string, nullable: true },
              solo_queue_lp: { type: :integer, nullable: true },
              current_rank: { type: :string },
              win_rate: { type: :number, format: :float },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: %w[id summoner_name role status]
          },
          Match: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              match_type: { type: :string, enum: %w[official scrim tournament] },
              game_start: { type: :string, format: 'date-time' },
              game_duration: { type: :integer },
              victory: { type: :boolean },
              opponent_name: { type: :string, nullable: true },
              our_score: { type: :integer, nullable: true },
              opponent_score: { type: :integer, nullable: true },
              result: { type: :string },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: %w[id match_type]
          },
          Pagination: {
            type: :object,
            properties: {
              current_page: { type: :integer },
              per_page: { type: :integer },
              total_pages: { type: :integer },
              total_count: { type: :integer },
              has_next_page: { type: :boolean },
              has_prev_page: { type: :boolean }
            }
          }
        }
      },
      security: [
        { bearerAuth: [] }
      ]
    }
  }

  # Specify the format of the output Swagger file
  config.swagger_format = :yaml
end
