# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Scouting Regions API', type: :request do
  describe 'GET /api/v1/scouting/regions' do
    it 'returns regions wrapped in data without requiring authentication' do
      get '/api/v1/scouting/regions'

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body).to be_a(Hash)
      expect(body['data']).to be_present
      regions = body['data']['regions'] || body['data']
      expect(regions).to be_an(Array)
      expect(regions).not_to be_empty

      sample = regions.first
      expect(sample.keys).to include('code', 'name', 'platform')
    end
  end
end
