# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Meta Intelligence API', type: :request do
  let(:org)   { create(:organization) }
  let(:user)  { create(:user, :admin, organization: org) }

  # ---------------------------------------------------------------------------
  # GET /api/v1/meta/items
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/meta/items' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/meta/items'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'returns 200' do
        get '/api/v1/meta/items', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns items array and total' do
        get '/api/v1/meta/items', headers: auth_headers(user)
        data = json_response[:data]
        expect(data).to have_key(:items)
        expect(data).to have_key(:total)
        expect(data[:items]).to be_an(Array)
      end

      it 'returns weighted_win_rate within [0, 100] for each item' do
        get '/api/v1/meta/items', headers: auth_headers(user)
        json_response[:data][:items].each do |item|
          expect(item[:weighted_win_rate]).to be_between(0, 100)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/meta/items/:id
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/meta/items/:id' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/meta/items/3153'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when item does not exist in analytics' do
      it 'returns 404' do
        get '/api/v1/meta/items/9999999', headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Builds — index
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/meta/builds' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/meta/builds'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with no builds' do
      it 'returns 200 with empty array' do
        get '/api/v1/meta/builds', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:builds]).to eq([])
      end
    end

    context 'with builds belonging to this org' do
      let!(:build_jinx) { create(:saved_build, :jinx_adc, organization: org) }
      let!(:build_garen) { create(:saved_build, champion: 'Garen', role: 'top', organization: org) }

      it 'returns all org builds' do
        get '/api/v1/meta/builds', headers: auth_headers(user)
        expect(json_response[:data][:builds].size).to eq(2)
      end

      it 'filters by champion' do
        get '/api/v1/meta/builds', params: { champion: 'Jinx' }, headers: auth_headers(user)
        champions = json_response[:data][:builds].map { |b| b[:champion] }
        expect(champions).to all(eq('Jinx'))
      end

      it 'filters by role' do
        get '/api/v1/meta/builds', params: { role: 'top' }, headers: auth_headers(user)
        roles = json_response[:data][:builds].map { |b| b[:role] }
        expect(roles).to all(eq('top'))
      end

      it 'returns win_rate within [0, 100] for each build' do
        get '/api/v1/meta/builds', headers: auth_headers(user)
        json_response[:data][:builds].each do |build|
          expect(build[:win_rate]).to be_between(0, 100) if build[:win_rate]
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Builds — show
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/meta/builds/:id' do
    let!(:build) { create(:saved_build, :jinx_adc, organization: org) }

    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/meta/builds/#{build.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when build belongs to this org' do
      it 'returns 200 with build data' do
        get "/api/v1/meta/builds/#{build.id}", headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:build][:champion]).to eq('Jinx')
      end
    end

    context 'when build belongs to another org' do
      let(:other_org)   { create(:organization) }
      let(:other_build) { create(:saved_build, organization: other_org) }

      it 'returns 404' do
        get "/api/v1/meta/builds/#{other_build.id}", headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when build does not exist' do
      it 'returns 404' do
        get '/api/v1/meta/builds/0', headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Builds — create
  # ---------------------------------------------------------------------------

  describe 'POST /api/v1/meta/builds' do
    let(:valid_params) do
      {
        build: {
          champion: 'Jinx',
          role: 'adc',
          patch_version: '14.24',
          title: 'Standard Jinx ADC',
          items: [3153, 3006, 3031, 3036, 3072]
        }
      }
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/meta/builds', params: valid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid params' do
      it 'returns 201' do
        post '/api/v1/meta/builds', params: valid_params.to_json, headers: auth_headers(user)
        expect(response).to have_http_status(:created)
      end

      it 'creates a manual build' do
        post '/api/v1/meta/builds', params: valid_params.to_json, headers: auth_headers(user)
        expect(json_response[:data][:build][:data_source]).to eq('manual')
      end

      it 'scopes the new build to the current org' do
        post '/api/v1/meta/builds', params: valid_params.to_json, headers: auth_headers(user)
        build_id = json_response[:data][:build][:id]
        expect(org.saved_builds.find_by(id: build_id)).to be_present
      end

      it 'sets champion correctly' do
        post '/api/v1/meta/builds', params: valid_params.to_json, headers: auth_headers(user)
        expect(json_response[:data][:build][:champion]).to eq('Jinx')
      end
    end

    context 'with invalid role' do
      it 'returns 422' do
        params = valid_params.deep_merge(build: { role: 'carry' })
        post '/api/v1/meta/builds', params: params.to_json, headers: auth_headers(user)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without champion (required field)' do
      it 'returns 422' do
        params = { build: { role: 'adc', items: [3153] } }
        post '/api/v1/meta/builds', params: params.to_json, headers: auth_headers(user)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Builds — update
  # ---------------------------------------------------------------------------

  describe 'PATCH /api/v1/meta/builds/:id' do
    let!(:build) { create(:saved_build, :jinx_adc, organization: org, title: 'Old Title') }

    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/meta/builds/#{build.id}",
              params: { build: { title: 'New' } }.to_json,
              headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid update' do
      it 'returns 200' do
        patch "/api/v1/meta/builds/#{build.id}",
              params: { build: { title: 'New Title' } }.to_json,
              headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'updates the title' do
        patch "/api/v1/meta/builds/#{build.id}",
              params: { build: { title: 'New Title' } }.to_json,
              headers: auth_headers(user)
        expect(json_response[:data][:build][:title]).to eq('New Title')
      end
    end

    context 'when build belongs to another org' do
      let(:other_build) { create(:saved_build, organization: create(:organization)) }

      it 'returns 404' do
        patch "/api/v1/meta/builds/#{other_build.id}",
              params: { build: { title: 'Hijacked' } }.to_json,
              headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Builds — destroy
  # ---------------------------------------------------------------------------

  describe 'DELETE /api/v1/meta/builds/:id' do
    let!(:build) { create(:saved_build, organization: org) }

    context 'when unauthenticated' do
      it 'returns 401' do
        delete "/api/v1/meta/builds/#{build.id}",
               headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with own build' do
      it 'returns 200' do
        delete "/api/v1/meta/builds/#{build.id}", headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'removes the build from the database' do
        delete "/api/v1/meta/builds/#{build.id}", headers: auth_headers(user)
        expect(SavedBuild.find_by(id: build.id)).to be_nil
      end
    end

    context 'when build belongs to another org' do
      let(:other_build) { create(:saved_build, organization: create(:organization)) }

      it 'returns 404' do
        delete "/api/v1/meta/builds/#{other_build.id}", headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Builds — aggregate
  # ---------------------------------------------------------------------------

  describe 'POST /api/v1/meta/builds/aggregate' do
    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/meta/builds/aggregate'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'as admin' do
      it 'returns 200 and enqueues the job' do
        post '/api/v1/meta/builds/aggregate', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as a non-admin member' do
      let(:member) { create(:user, organization: org) }

      it 'returns 403' do
        post '/api/v1/meta/builds/aggregate', headers: auth_headers(member)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/meta/champions/:champion
  # ---------------------------------------------------------------------------

  describe 'GET /api/v1/meta/champions/:champion' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/meta/champions/Jinx'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with no builds for the champion' do
      it 'returns 200 with nil optimal_build' do
        get '/api/v1/meta/champions/Jinx', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data[:champion]).to eq('Jinx')
        expect(data[:optimal_build]).to be_nil
        expect(data[:all_builds]).to eq([])
      end
    end

    context 'with builds for the champion' do
      before do
        create(:saved_build, :jinx_adc, :with_sufficient_sample, organization: org, win_rate: 62.5)
        create(:saved_build, :jinx_adc, :with_sufficient_sample, organization: org, win_rate: 55.0)
      end

      it 'returns 200 with optimal_build being the highest win_rate build' do
        get '/api/v1/meta/champions/Jinx', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data[:optimal_build][:win_rate]).to eq(62.5)
      end

      it 'returns at most 5 builds in all_builds' do
        3.times { create(:saved_build, :jinx_adc, :with_sufficient_sample, organization: org) }
        get '/api/v1/meta/champions/Jinx', headers: auth_headers(user)
        expect(json_response[:data][:all_builds].size).to be <= 5
      end

      it 'does not return builds from another org' do
        other_build = create(:saved_build, :jinx_adc, :with_sufficient_sample,
                             organization: create(:organization), win_rate: 99.9)
        get '/api/v1/meta/champions/Jinx', headers: auth_headers(user)
        ids = json_response[:data][:all_builds].map { |b| b[:id] }
        expect(ids).not_to include(other_build.id)
      end

      it 'filters by role when param provided' do
        create(:saved_build, :with_sufficient_sample, champion: 'Jinx', role: 'top',
               organization: org, games_played: 20)
        get '/api/v1/meta/champions/Jinx', params: { role: 'adc' }, headers: auth_headers(user)
        json_response[:data][:all_builds].each do |b|
          expect(b[:role]).to eq('adc')
        end
      end
    end
  end
end
