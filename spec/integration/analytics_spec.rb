require 'swagger_helper'

RSpec.describe 'Analytics API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  path '/api/v1/analytics/performance' do
    get 'Get team performance analytics' do
      tags 'Analytics'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Returns comprehensive team and player performance metrics'

      parameter name: :start_date, in: :query, type: :string, required: false, description: 'Start date (YYYY-MM-DD)'
      parameter name: :end_date, in: :query, type: :string, required: false, description: 'End date (YYYY-MM-DD)'
      parameter name: :time_period, in: :query, type: :string, required: false, description: 'Predefined period (week, month, season)'
      parameter name: :player_id, in: :query, type: :string, required: false, description: 'Player ID for individual stats'

      response '200', 'performance data retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                team_overview: {
                  type: :object,
                  properties: {
                    total_matches: { type: :integer },
                    wins: { type: :integer },
                    losses: { type: :integer },
                    win_rate: { type: :number, format: :float },
                    avg_game_duration: { type: :integer },
                    avg_kda: { type: :number, format: :float },
                    avg_kills_per_game: { type: :number, format: :float },
                    avg_deaths_per_game: { type: :number, format: :float },
                    avg_assists_per_game: { type: :number, format: :float }
                  }
                },
                best_performers: { type: :array },
                win_rate_trend: { type: :array }
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

  path '/api/v1/analytics/team-comparison' do
    get 'Compare team players performance' do
      tags 'Analytics'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Provides side-by-side comparison of all team players'

      parameter name: :start_date, in: :query, type: :string, required: false, description: 'Start date (YYYY-MM-DD)'
      parameter name: :end_date, in: :query, type: :string, required: false, description: 'End date (YYYY-MM-DD)'

      response '200', 'comparison data retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                players: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {
                      player: { '$ref' => '#/components/schemas/Player' },
                      games_played: { type: :integer },
                      kda: { type: :number, format: :float },
                      avg_damage: { type: :integer },
                      avg_gold: { type: :integer },
                      avg_cs: { type: :number, format: :float },
                      avg_vision_score: { type: :number, format: :float },
                      avg_performance_score: { type: :number, format: :float },
                      multikills: {
                        type: :object,
                        properties: {
                          double: { type: :integer },
                          triple: { type: :integer },
                          quadra: { type: :integer },
                          penta: { type: :integer }
                        }
                      }
                    }
                  }
                },
                team_averages: { type: :object },
                role_rankings: { type: :object }
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

  path '/api/v1/analytics/champions/{player_id}' do
    parameter name: :player_id, in: :path, type: :string, description: 'Player ID'

    get 'Get player champion statistics' do
      tags 'Analytics'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Returns champion pool and performance statistics for a specific player'

      response '200', 'champion stats retrieved' do
        let(:player_id) { create(:player, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                player: { '$ref' => '#/components/schemas/Player' },
                champion_stats: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {
                      champion: { type: :string },
                      games_played: { type: :integer },
                      win_rate: { type: :number, format: :float },
                      avg_kda: { type: :number, format: :float },
                      mastery_grade: { type: :string, enum: %w[S A B C D] }
                    }
                  }
                },
                top_champions: { type: :array },
                champion_diversity: {
                  type: :object,
                  properties: {
                    total_champions: { type: :integer },
                    highly_played: { type: :integer },
                    average_games: { type: :number, format: :float }
                  }
                }
              }
            }
          }

        run_test!
      end

      response '404', 'player not found' do
        let(:player_id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/analytics/kda-trend/{player_id}' do
    parameter name: :player_id, in: :path, type: :string, description: 'Player ID'

    get 'Get player KDA trend over recent matches' do
      tags 'Analytics'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Shows KDA performance trend for the last 50 matches'

      response '200', 'KDA trend retrieved' do
        let(:player_id) { create(:player, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                player: { '$ref' => '#/components/schemas/Player' },
                kda_by_match: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {
                      match_id: { type: :string },
                      date: { type: :string, format: 'date-time' },
                      kills: { type: :integer },
                      deaths: { type: :integer },
                      assists: { type: :integer },
                      kda: { type: :number, format: :float },
                      champion: { type: :string },
                      victory: { type: :boolean }
                    }
                  }
                },
                averages: {
                  type: :object,
                  properties: {
                    last_10_games: { type: :number, format: :float },
                    last_20_games: { type: :number, format: :float },
                    overall: { type: :number, format: :float }
                  }
                }
              }
            }
          }

        run_test!
      end

      response '404', 'player not found' do
        let(:player_id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/analytics/laning/{player_id}' do
    parameter name: :player_id, in: :path, type: :string, description: 'Player ID'

    get 'Get player laning phase statistics' do
      tags 'Analytics'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Returns CS and gold performance metrics for laning phase'

      response '200', 'laning stats retrieved' do
        let(:player_id) { create(:player, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                player: { '$ref' => '#/components/schemas/Player' },
                cs_performance: {
                  type: :object,
                  properties: {
                    avg_cs_total: { type: :number, format: :float },
                    avg_cs_per_min: { type: :number, format: :float },
                    best_cs_game: { type: :integer },
                    worst_cs_game: { type: :integer }
                  }
                },
                gold_performance: {
                  type: :object,
                  properties: {
                    avg_gold: { type: :integer },
                    best_gold_game: { type: :integer },
                    worst_gold_game: { type: :integer }
                  }
                },
                cs_by_match: { type: :array }
              }
            }
          }

        run_test!
      end

      response '404', 'player not found' do
        let(:player_id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/analytics/teamfights/{player_id}' do
    parameter name: :player_id, in: :path, type: :string, description: 'Player ID'

    get 'Get player teamfight performance' do
      tags 'Analytics'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Returns damage dealt/taken and teamfight participation metrics'

      response '200', 'teamfight stats retrieved' do
        let(:player_id) { create(:player, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                player: { '$ref' => '#/components/schemas/Player' },
                damage_performance: {
                  type: :object,
                  properties: {
                    avg_damage_dealt: { type: :integer },
                    avg_damage_taken: { type: :integer },
                    best_damage_game: { type: :integer },
                    avg_damage_per_min: { type: :integer }
                  }
                },
                participation: {
                  type: :object,
                  properties: {
                    avg_kills: { type: :number, format: :float },
                    avg_assists: { type: :number, format: :float },
                    avg_deaths: { type: :number, format: :float },
                    multikill_stats: {
                      type: :object,
                      properties: {
                        double_kills: { type: :integer },
                        triple_kills: { type: :integer },
                        quadra_kills: { type: :integer },
                        penta_kills: { type: :integer }
                      }
                    }
                  }
                },
                by_match: { type: :array }
              }
            }
          }

        run_test!
      end

      response '404', 'player not found' do
        let(:player_id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/analytics/vision/{player_id}' do
    parameter name: :player_id, in: :path, type: :string, description: 'Player ID'

    get 'Get player vision control statistics' do
      tags 'Analytics'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Returns ward placement, vision score, and vision control metrics'

      response '200', 'vision stats retrieved' do
        let(:player_id) { create(:player, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                player: { '$ref' => '#/components/schemas/Player' },
                vision_stats: {
                  type: :object,
                  properties: {
                    avg_vision_score: { type: :number, format: :float },
                    avg_wards_placed: { type: :number, format: :float },
                    avg_wards_killed: { type: :number, format: :float },
                    best_vision_game: { type: :integer },
                    total_wards_placed: { type: :integer },
                    total_wards_killed: { type: :integer }
                  }
                },
                vision_per_min: { type: :number, format: :float },
                by_match: { type: :array },
                role_comparison: {
                  type: :object,
                  properties: {
                    player_avg: { type: :number, format: :float },
                    role_avg: { type: :number, format: :float },
                    percentile: { type: :integer }
                  }
                }
              }
            }
          }

        run_test!
      end

      response '404', 'player not found' do
        let(:player_id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
