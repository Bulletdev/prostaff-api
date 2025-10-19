require 'swagger_helper'

RSpec.describe 'Matches API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  path '/api/v1/matches' do
    get 'List all matches' do
      tags 'Matches'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'
      parameter name: :match_type, in: :query, type: :string, required: false, description: 'Filter by match type (official, scrim, tournament)'
      parameter name: :result, in: :query, type: :string, required: false, description: 'Filter by result (victory, defeat)'
      parameter name: :start_date, in: :query, type: :string, required: false, description: 'Start date for filtering (YYYY-MM-DD)'
      parameter name: :end_date, in: :query, type: :string, required: false, description: 'End date for filtering (YYYY-MM-DD)'
      parameter name: :days, in: :query, type: :integer, required: false, description: 'Filter recent matches (e.g., 7, 30, 90 days)'
      parameter name: :opponent, in: :query, type: :string, required: false, description: 'Filter by opponent name'
      parameter name: :tournament, in: :query, type: :string, required: false, description: 'Filter by tournament name'
      parameter name: :sort_by, in: :query, type: :string, required: false, description: 'Sort field (game_start, game_duration, match_type, victory)'
      parameter name: :sort_order, in: :query, type: :string, required: false, description: 'Sort order (asc, desc)'

      response '200', 'matches found' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                matches: {
                  type: :array,
                  items: { '$ref' => '#/components/schemas/Match' }
                },
                pagination: { '$ref' => '#/components/schemas/Pagination' },
                summary: {
                  type: :object,
                  properties: {
                    total: { type: :integer },
                    victories: { type: :integer },
                    defeats: { type: :integer },
                    win_rate: { type: :number, format: :float },
                    by_type: { type: :object },
                    avg_duration: { type: :integer }
                  }
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

    post 'Create a match' do
      tags 'Matches'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :match, in: :body, schema: {
        type: :object,
        properties: {
          match: {
            type: :object,
            properties: {
              match_type: { type: :string, enum: %w[official scrim tournament] },
              game_start: { type: :string, format: 'date-time' },
              game_end: { type: :string, format: 'date-time' },
              game_duration: { type: :integer, description: 'Duration in seconds' },
              opponent_name: { type: :string },
              opponent_tag: { type: :string },
              victory: { type: :boolean },
              our_side: { type: :string, enum: %w[blue red] },
              our_score: { type: :integer },
              opponent_score: { type: :integer },
              tournament_name: { type: :string },
              stage: { type: :string },
              patch_version: { type: :string },
              vod_url: { type: :string },
              notes: { type: :string }
            },
            required: %w[match_type game_start victory]
          }
        }
      }

      response '201', 'match created' do
        let(:match) do
          {
            match: {
              match_type: 'scrim',
              game_start: Time.current.iso8601,
              victory: true,
              our_score: 1,
              opponent_score: 0,
              opponent_name: 'Enemy Team'
            }
          }
        end

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                match: { '$ref' => '#/components/schemas/Match' }
              }
            }
          }

        run_test!
      end

      response '422', 'invalid request' do
        let(:match) { { match: { match_type: 'invalid' } } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/matches/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Match ID'

    get 'Show match details' do
      tags 'Matches'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'match found' do
        let(:id) { create(:match, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                match: { '$ref' => '#/components/schemas/Match' },
                player_stats: {
                  type: :array,
                  items: { '$ref' => '#/components/schemas/PlayerMatchStat' }
                },
                team_composition: { type: :object },
                mvp: { '$ref' => '#/components/schemas/Player', nullable: true }
              }
            }
          }

        run_test!
      end

      response '404', 'match not found' do
        let(:id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    patch 'Update a match' do
      tags 'Matches'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :match, in: :body, schema: {
        type: :object,
        properties: {
          match: {
            type: :object,
            properties: {
              match_type: { type: :string },
              victory: { type: :boolean },
              notes: { type: :string },
              vod_url: { type: :string }
            }
          }
        }
      }

      response '200', 'match updated' do
        let(:id) { create(:match, organization: organization).id }
        let(:match) { { match: { notes: 'Updated notes' } } }

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                match: { '$ref' => '#/components/schemas/Match' }
              }
            }
          }

        run_test!
      end
    end

    delete 'Delete a match' do
      tags 'Matches'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'match deleted' do
        let(:user) { create(:user, :owner, organization: organization) }
        let(:id) { create(:match, organization: organization).id }

        schema type: :object,
          properties: {
            message: { type: :string }
          }

        run_test!
      end
    end
  end

  path '/api/v1/matches/{id}/stats' do
    parameter name: :id, in: :path, type: :string, description: 'Match ID'

    get 'Get match statistics' do
      tags 'Matches'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'statistics retrieved' do
        let(:id) { create(:match, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                match: { '$ref' => '#/components/schemas/Match' },
                team_stats: {
                  type: :object,
                  properties: {
                    total_kills: { type: :integer },
                    total_deaths: { type: :integer },
                    total_assists: { type: :integer },
                    total_gold: { type: :integer },
                    total_damage: { type: :integer },
                    total_cs: { type: :integer },
                    total_vision_score: { type: :integer },
                    avg_kda: { type: :number, format: :float }
                  }
                }
              }
            }
          }

        run_test!
      end
    end
  end

  path '/api/v1/matches/import' do
    post 'Import matches from Riot API' do
      tags 'Matches'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :import_params, in: :body, schema: {
        type: :object,
        properties: {
          player_id: { type: :string, description: 'Player ID to import matches for' },
          count: { type: :integer, description: 'Number of matches to import (1-100)', default: 20 }
        },
        required: %w[player_id]
      }

      response '200', 'import started' do
        let(:player) { create(:player, organization: organization, riot_puuid: 'test-puuid') }
        let(:import_params) { { player_id: player.id, count: 10 } }

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                job_id: { type: :string },
                player_id: { type: :string },
                count: { type: :integer }
              }
            }
          }

        run_test!
      end

      response '400', 'player missing PUUID' do
        let(:player) { create(:player, organization: organization, riot_puuid: nil) }
        let(:import_params) { { player_id: player.id } }

        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
