# frozen_string_literal: true

require 'rails_helper'
require 'yaml'

RSpec.describe 'Horizontal scaling configuration' do
  # Redis.new validates kwargs in RedisClient::Config#initialize synchronously,
  # before any TCP connection. The cache store is lazy (first cache access),
  # so invalid options bypass boot checks and only blow up in production.
  # This test catches unknown keyword errors without needing a live Redis.
  describe 'config/environments/production.rb RedisCacheStore options' do
    # Mirror the options passed to RedisCacheStore in production.rb.
    # Update this hash whenever production.rb cache_store config changes.
    let(:redis_client_options) do
      { url: 'redis://localhost:6379/0', reconnect_attempts: 3 }
    end

    it 'passes only valid keywords to the Redis client constructor' do
      msg = 'RedisCacheStore is lazy-initialized, so invalid kwargs only surface at ' \
            'first cache access in production. Keep this hash in sync with production.rb.'
      expect { Redis.new(**redis_client_options) }.not_to raise_error(ArgumentError), msg
    end
  end

  describe 'database advisory locks' do
    it 'is enabled to serialize concurrent migrations across replicas at startup' do
      db_config = ActiveRecord::Base.connection_db_config.configuration_hash
      msg = 'advisory_locks: false disables the PostgreSQL lock that prevents two api ' \
            'replicas from running the same migration simultaneously on startup'
      expect(db_config[:advisory_locks]).not_to eq(false), msg
    end
  end

  describe 'docker/docker-compose.production.yml' do
    subject(:compose) do
      YAML.safe_load(
        Rails.root.join('docker/docker-compose.production.yml').read,
        permitted_classes: [],
        symbolize_names: false
      )
    end

    let(:api_service) { compose.dig('services', 'api') }

    it 'runs the api service with 2 replicas' do
      replicas = api_service.dig('deploy', 'replicas')
      expect(replicas).to eq(2)
    end

    it 'does not define container_name on the api service' do
      msg = 'container_name on api is incompatible with deploy.replicas — ' \
            'Docker would fail with a duplicate name error on the second container'
      expect(api_service['container_name']).to be_nil, msg
    end

    it 'uses expose instead of host-bound ports on the api service' do
      ports = api_service['ports']
      expose = Array(api_service['expose'])
      msg = 'ports: with a host bind (e.g. "3000:3000") conflicts with 2 replicas — ' \
            'only one container can bind a given host port'
      expect(ports).to be_nil, msg
      expect(expose).to include('3000').or(include(3000))
    end

    it 'configures stop_grace_period above Puma worker_shutdown_timeout (30s)' do
      grace = api_service['stop_grace_period']
      msg = 'stop_grace_period must be > worker_shutdown_timeout (30s) so Docker waits ' \
            'for Puma to drain in-flight requests before force-killing the container'
      expect(grace).to eq('35s'), msg
    end

    it 'does not scale the sidekiq service' do
      sidekiq_replicas = compose.dig('services', 'sidekiq', 'deploy', 'replicas')
      msg = '2 Sidekiq containers would execute the 9 scheduled cron jobs twice each run'
      expect(sidekiq_replicas).to be_nil.or(eq(1)), msg
    end
  end
end
