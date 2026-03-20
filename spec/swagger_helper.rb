# frozen_string_literal: true

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
                  details: {}
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
              timezone: { type: :string, nullable: true },
              language: { type: :string, nullable: true },
              created_at: { type: :string },
              updated_at: { type: :string }
            },
            required: %w[id email full_name role]
          },
          Organization: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              name: { type: :string },
              region: { type: :string },
              tier: { type: :string, enum: %w[tier_3_amateur tier_2_semi_pro tier_1_professional] },
              created_at: { type: :string },
              updated_at: { type: :string }
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
              game_duration: { type: :integer, nullable: true },
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
          },
          PlayerMatchStat: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              player_id: { type: :string, format: :uuid },
              match_id: { type: :string, format: :uuid },
              kills: { type: :integer },
              deaths: { type: :integer },
              assists: { type: :integer },
              cs: { type: :integer },
              vision_score: { type: :integer },
              champion: { type: :string, nullable: true },
              role: { type: :string, nullable: true },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            }
          },
          VodReview: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              title: { type: :string },
              video_url: { type: :string },
              vod_platform: { type: :string, nullable: true },
              summary: { type: :string, nullable: true },
              status: { type: :string },
              tags: { type: :array, items: { type: :string } },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            }
          },
          VodTimestamp: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              vod_review_id: { type: :string, format: :uuid },
              timestamp_seconds: { type: :integer },
              title: { type: :string },
              description: { type: :string, nullable: true },
              category: { type: :string, nullable: true },
              importance: { type: :string },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            }
          },
          Schedule: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              title: { type: :string },
              event_type: { type: :string, nullable: true },
              description: { type: :string, nullable: true },
              start_time: { type: :string, format: 'date-time', nullable: true },
              end_time: { type: :string, format: 'date-time', nullable: true },
              status: { type: :string },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            }
          },
          ScoutingTarget: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              summoner_name: { type: :string },
              region: { type: :string, nullable: true },
              role: { type: :string, nullable: true },
              tier: { type: :string, nullable: true },
              status: { type: :string },
              notes: { type: :string, nullable: true },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            }
          },
          TeamGoal: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              title: { type: :string },
              description: { type: :string, nullable: true },
              category: { type: :string, nullable: true },
              metric_type: { type: :string, nullable: true },
              target_value: { type: :number, nullable: true },
              current_value: { type: :number, nullable: true },
              status: { type: :string },
              start_date: { type: :string, format: 'date', nullable: true },
              end_date: { type: :string, format: 'date', nullable: true },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
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
