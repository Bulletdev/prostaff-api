# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health endpoints', type: :request do
  # Health endpoints are public — no auth required

  describe 'GET /health/live' do
    it 'returns 200' do
      get '/health/live'
      expect(response).to have_http_status(:ok)
    end

    it 'returns status ok' do
      get '/health/live'
      body = JSON.parse(response.body)
      expect(body['status']).to eq('ok')
    end

    it 'returns service name' do
      get '/health/live'
      body = JSON.parse(response.body)
      expect(body['service']).to eq('ProStaff API')
    end

    it 'returns a timestamp' do
      get '/health/live'
      body = JSON.parse(response.body)
      expect(body['timestamp']).to be_present
      expect { Time.parse(body['timestamp']) }.not_to raise_error
    end

    it 'never checks Redis (no redis key in response)' do
      get '/health/live'
      body = JSON.parse(response.body)
      expect(body).not_to have_key('checks')
    end
  end

  describe 'GET /health/ready' do
    before do
      allow_any_instance_of(HealthController).to receive(:check_redis).and_return({ status: 'ok' })
      allow_any_instance_of(HealthController).to receive(:check_meilisearch).and_return({ status: 'ok' })
    end

    it 'returns 200 when database is reachable' do
      get '/health/ready'
      expect(response).to have_http_status(:ok)
    end

    it 'returns checks with database key' do
      get '/health/ready'
      body = JSON.parse(response.body)
      expect(body['checks']).to have_key('database')
    end

    it 'returns database status ok' do
      get '/health/ready'
      body = JSON.parse(response.body)
      expect(body.dig('checks', 'database', 'status')).to eq('ok')
    end

    it 'returns redis and meilisearch check keys' do
      get '/health/ready'
      body = JSON.parse(response.body)
      expect(body['checks']).to have_key('redis')
      expect(body['checks']).to have_key('meilisearch')
    end

    it 'returns 503 when database is unavailable' do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(PG::ConnectionBad, 'down')
      get '/health/ready'
      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe 'GET /health/detailed' do
    before do
      allow_any_instance_of(HealthController).to receive(:check_redis).and_return({ status: 'ok' })
      allow_any_instance_of(HealthController).to receive(:check_meilisearch).and_return({ status: 'ok' })
    end

    it 'returns same format as /health/ready' do
      get '/health/detailed'
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to have_key('checks')
    end
  end

  describe 'GET /health' do
    it 'returns 200 with static ok response' do
      get '/health'
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('ok')
    end
  end
end
