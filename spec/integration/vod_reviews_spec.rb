require 'swagger_helper'

RSpec.describe 'VOD Reviews API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  path '/api/v1/vod-reviews' do
    get 'List all VOD reviews' do
      tags 'VOD Reviews'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'
      parameter name: :match_id, in: :query, type: :string, required: false, description: 'Filter by match ID'
      parameter name: :reviewed_by_id, in: :query, type: :string, required: false, description: 'Filter by reviewer ID'
      parameter name: :status, in: :query, type: :string, required: false, description: 'Filter by status (draft, published, archived)'

      response '200', 'VOD reviews found' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                vod_reviews: {
                  type: :array,
                  items: { '$ref' => '#/components/schemas/VodReview' }
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

    post 'Create a VOD review' do
      tags 'VOD Reviews'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :vod_review, in: :body, schema: {
        type: :object,
        properties: {
          vod_review: {
            type: :object,
            properties: {
              match_id: { type: :string },
              title: { type: :string },
              vod_url: { type: :string },
              vod_platform: { type: :string, enum: %w[youtube twitch gdrive other] },
              summary: { type: :string },
              status: { type: :string, enum: %w[draft published archived], default: 'draft' },
              tags: { type: :array, items: { type: :string } }
            },
            required: %w[title vod_url]
          }
        }
      }

      response '201', 'VOD review created' do
        let(:match) { create(:match, organization: organization) }
        let(:vod_review) do
          {
            vod_review: {
              match_id: match.id,
              title: 'Game Review vs Team X',
              vod_url: 'https://youtube.com/watch?v=test',
              vod_platform: 'youtube',
              summary: 'Strong early game, need to work on mid-game transitions',
              status: 'draft'
            }
          }
        end

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                vod_review: { '$ref' => '#/components/schemas/VodReview' }
              }
            }
          }

        run_test!
      end

      response '422', 'invalid request' do
        let(:vod_review) { { vod_review: { title: '' } } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/vod-reviews/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'VOD Review ID'

    get 'Show VOD review details' do
      tags 'VOD Reviews'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'VOD review found' do
        let(:id) { create(:vod_review, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                vod_review: { '$ref' => '#/components/schemas/VodReview' },
                timestamps: {
                  type: :array,
                  items: { '$ref' => '#/components/schemas/VodTimestamp' }
                }
              }
            }
          }

        run_test!
      end

      response '404', 'VOD review not found' do
        let(:id) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    patch 'Update a VOD review' do
      tags 'VOD Reviews'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :vod_review, in: :body, schema: {
        type: :object,
        properties: {
          vod_review: {
            type: :object,
            properties: {
              title: { type: :string },
              summary: { type: :string },
              status: { type: :string }
            }
          }
        }
      }

      response '200', 'VOD review updated' do
        let(:id) { create(:vod_review, organization: organization).id }
        let(:vod_review) { { vod_review: { status: 'published' } } }

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                vod_review: { '$ref' => '#/components/schemas/VodReview' }
              }
            }
          }

        run_test!
      end
    end

    delete 'Delete a VOD review' do
      tags 'VOD Reviews'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'VOD review deleted' do
        let(:id) { create(:vod_review, organization: organization).id }

        schema type: :object,
          properties: {
            message: { type: :string }
          }

        run_test!
      end
    end
  end

  path '/api/v1/vod-reviews/{vod_review_id}/timestamps' do
    parameter name: :vod_review_id, in: :path, type: :string, description: 'VOD Review ID'

    get 'List timestamps for a VOD review' do
      tags 'VOD Reviews'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :category, in: :query, type: :string, required: false, description: 'Filter by category (mistake, good_play, objective, teamfight, other)'
      parameter name: :importance, in: :query, type: :string, required: false, description: 'Filter by importance (low, medium, high, critical)'

      response '200', 'timestamps found' do
        let(:vod_review_id) { create(:vod_review, organization: organization).id }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                timestamps: {
                  type: :array,
                  items: { '$ref' => '#/components/schemas/VodTimestamp' }
                }
              }
            }
          }

        run_test!
      end
    end

    post 'Create a timestamp' do
      tags 'VOD Reviews'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :vod_timestamp, in: :body, schema: {
        type: :object,
        properties: {
          vod_timestamp: {
            type: :object,
            properties: {
              timestamp_seconds: { type: :integer, description: 'Timestamp in seconds' },
              title: { type: :string },
              description: { type: :string },
              category: { type: :string, enum: %w[mistake good_play objective teamfight other] },
              importance: { type: :string, enum: %w[low medium high critical] },
              target_type: { type: :string, enum: %w[team player], description: 'Who this timestamp is about' },
              target_player_id: { type: :string, description: 'Player ID if target_type is player' },
              tags: { type: :array, items: { type: :string } }
            },
            required: %w[timestamp_seconds title category importance]
          }
        }
      }

      response '201', 'timestamp created' do
        let(:vod_review_id) { create(:vod_review, organization: organization).id }
        let(:player) { create(:player, organization: organization) }
        let(:vod_timestamp) do
          {
            vod_timestamp: {
              timestamp_seconds: 420,
              title: 'Missed flash timing',
              description: 'Should have flashed earlier to secure kill',
              category: 'mistake',
              importance: 'high',
              target_type: 'player',
              target_player_id: player.id
            }
          }
        end

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                timestamp: { '$ref' => '#/components/schemas/VodTimestamp' }
              }
            }
          }

        run_test!
      end
    end
  end

  path '/api/v1/vod-timestamps/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'VOD Timestamp ID'

    patch 'Update a timestamp' do
      tags 'VOD Reviews'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :vod_timestamp, in: :body, schema: {
        type: :object,
        properties: {
          vod_timestamp: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              importance: { type: :string }
            }
          }
        }
      }

      response '200', 'timestamp updated' do
        let(:vod_review) { create(:vod_review, organization: organization) }
        let(:id) { create(:vod_timestamp, vod_review: vod_review).id }
        let(:vod_timestamp) { { vod_timestamp: { title: 'Updated title' } } }

        schema type: :object,
          properties: {
            message: { type: :string },
            data: {
              type: :object,
              properties: {
                timestamp: { '$ref' => '#/components/schemas/VodTimestamp' }
              }
            }
          }

        run_test!
      end
    end

    delete 'Delete a timestamp' do
      tags 'VOD Reviews'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'timestamp deleted' do
        let(:vod_review) { create(:vod_review, organization: organization) }
        let(:id) { create(:vod_timestamp, vod_review: vod_review).id }

        schema type: :object,
          properties: {
            message: { type: :string }
          }

        run_test!
      end
    end
  end
end
