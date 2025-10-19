require 'swagger_helper'

RSpec.describe 'Riot Data API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  path '/api/v1/riot-data/champions' do
    get 'Get champions ID map' do
      tags 'Riot Data'
      produces 'application/json'

      response '200', 'champions retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                champions: { type: :object },
                count: { type: :integer }
              }
            }
          }

        run_test!
      end

      response '503', 'service unavailable' do
        schema '$ref' => '#/components/schemas/Error'

        before do
          allow_any_instance_of(DataDragonService).to receive(:champion_id_map)
            .and_raise(DataDragonService::DataDragonError.new('API unavailable'))
        end

        run_test!
      end
    end
  end

  path '/api/v1/riot-data/champions/{champion_key}' do
    parameter name: :champion_key, in: :path, type: :string, description: 'Champion key (e.g., "266" for Aatrox)'

    get 'Get champion details by key' do
      tags 'Riot Data'
      produces 'application/json'

      response '200', 'champion found' do
        let(:champion_key) { '266' }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                champion: { type: :object }
              }
            }
          }

        run_test!
      end

      response '404', 'champion not found' do
        let(:champion_key) { '99999' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/riot-data/all-champions' do
    get 'Get all champions details' do
      tags 'Riot Data'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'champions retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                champions: {
                  type: :array,
                  items: { type: :object }
                },
                count: { type: :integer }
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

  path '/api/v1/riot-data/items' do
    get 'Get all items' do
      tags 'Riot Data'
      produces 'application/json'

      response '200', 'items retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                items: { type: :object },
                count: { type: :integer }
              }
            }
          }

        run_test!
      end

      response '503', 'service unavailable' do
        schema '$ref' => '#/components/schemas/Error'

        before do
          allow_any_instance_of(DataDragonService).to receive(:items)
            .and_raise(DataDragonService::DataDragonError.new('API unavailable'))
        end

        run_test!
      end
    end
  end

  path '/api/v1/riot-data/summoner-spells' do
    get 'Get all summoner spells' do
      tags 'Riot Data'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'summoner spells retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                summoner_spells: { type: :object },
                count: { type: :integer }
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

  path '/api/v1/riot-data/version' do
    get 'Get current Data Dragon version' do
      tags 'Riot Data'
      produces 'application/json'

      response '200', 'version retrieved' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                version: { type: :string }
              }
            }
          }

        run_test!
      end

      response '503', 'service unavailable' do
        schema '$ref' => '#/components/schemas/Error'

        before do
          allow_any_instance_of(DataDragonService).to receive(:latest_version)
            .and_raise(DataDragonService::DataDragonError.new('API unavailable'))
        end

        run_test!
      end
    end
  end

  path '/api/v1/riot-data/clear-cache' do
    post 'Clear Data Dragon cache' do
      tags 'Riot Data'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'cache cleared' do
        let(:user) { create(:user, :owner, organization: organization) }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                message: { type: :string }
              }
            }
          }

        run_test!
      end

      response '403', 'forbidden' do
        let(:user) { create(:user, :member, organization: organization) }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/riot-data/update-cache' do
    post 'Update Data Dragon cache' do
      tags 'Riot Data'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'cache updated' do
        let(:user) { create(:user, :owner, organization: organization) }

        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                message: { type: :string },
                version: { type: :string },
                data: {
                  type: :object,
                  properties: {
                    champions: { type: :integer },
                    items: { type: :integer },
                    summoner_spells: { type: :integer }
                  }
                }
              }
            }
          }

        run_test!
      end

      response '403', 'forbidden' do
        let(:user) { create(:user, :member, organization: organization) }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
