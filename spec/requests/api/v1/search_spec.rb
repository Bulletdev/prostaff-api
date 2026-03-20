# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /api/v1/search', type: :request do
  let(:org)  { create(:organization) }
  let(:user) { create(:user, :admin, organization: org) }

  context 'when unauthenticated' do
    it 'returns 401' do
      get '/api/v1/search', params: { q: 'Jinx' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'without q param' do
    it 'returns 400 with PARAMETER_MISSING code' do
      get '/api/v1/search', headers: auth_headers(user)
      expect(response).to have_http_status(:bad_request)
      expect(json_response.dig(:error, :code)).to eq('PARAMETER_MISSING')
    end
  end

  context 'with blank q param' do
    it 'returns 400' do
      get '/api/v1/search', params: { q: '   ' }, headers: auth_headers(user)
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'with valid query' do
    it 'returns 200' do
      get '/api/v1/search', params: { q: 'test' }, headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
    end

    it 'returns query, types and results keys' do
      get '/api/v1/search', params: { q: 'test' }, headers: auth_headers(user)
      data = json_response[:data]
      expect(data).to have_key(:query)
      expect(data).to have_key(:types)
      expect(data).to have_key(:results)
    end

    it 'echoes back the query' do
      get '/api/v1/search', params: { q: 'brTT' }, headers: auth_headers(user)
      expect(json_response[:data][:query]).to eq('brTT')
    end
  end

  context 'with types filter' do
    it 'filters to allowed types only' do
      get '/api/v1/search', params: { q: 'test', types: 'players,invalid_type' },
          headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      types = json_response[:data][:types]
      expect(types).to include('players')
      expect(types).not_to include('invalid_type')
    end
  end

  context 'with null byte in query (injection attempt)' do
    it 'returns 400 (blank after stripping)' do
      get '/api/v1/search', params: { q: "\x00" }, headers: auth_headers(user)
      expect(response).to have_http_status(:bad_request)
    end
  end
end
