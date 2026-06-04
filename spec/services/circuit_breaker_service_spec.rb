# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CircuitBreakerService do
  let(:service_name) { "test_service_#{SecureRandom.hex(4)}" }

  # Flush all circuit breaker keys before each example so tests are isolated.
  before do
    Sidekiq.redis do |r|
      r.call('DEL', "circuit_breaker:#{service_name}:failures")
      r.call('DEL', "circuit_breaker:#{service_name}:state")
      r.call('DEL', "circuit_breaker:#{service_name}:opened_at")
    end
  end

  describe '.call' do
    it 'delegates to a new instance' do
      result = described_class.call(service_name) { 42 }
      expect(result).to eq(42)
    end
  end

  describe 'closed state (normal operation)' do
    it 'executes the block and returns its value' do
      result = described_class.call(service_name) { 'ok' }
      expect(result).to eq('ok')
    end

    it 'resets failure count after a success' do
      # Record failures below the threshold manually.
      Sidekiq.redis do |r|
        r.call('SET', "circuit_breaker:#{service_name}:failures",
               (CircuitBreakerService::FAILURE_THRESHOLD - 1).to_s)
      end

      described_class.call(service_name) { 'success' }

      failures = Sidekiq.redis { |r| r.call('GET', "circuit_breaker:#{service_name}:failures") }
      expect(failures).to be_nil
    end

    it 'increments failure count and re-raises on exception' do
      expect do
        described_class.call(service_name) { raise StandardError, 'boom' }
      end.to raise_error(StandardError, 'boom')

      failures = Sidekiq.redis do |r|
        r.call('GET', "circuit_breaker:#{service_name}:failures").to_i
      end
      expect(failures).to eq(1)
    end

    it 'opens the circuit after reaching the failure threshold' do
      threshold = CircuitBreakerService::FAILURE_THRESHOLD

      threshold.times do
        described_class.call(service_name) { raise StandardError, 'fail' }
      rescue StandardError
        nil
      end

      state = Sidekiq.redis { |r| r.call('GET', "circuit_breaker:#{service_name}:state") }
      expect(state).to eq('open')
    end
  end

  describe 'open state (tripped)' do
    before do
      # Force circuit into open state with a recent opened_at timestamp.
      Sidekiq.redis do |r|
        r.call('SET', "circuit_breaker:#{service_name}:state", 'open')
        r.call('SET', "circuit_breaker:#{service_name}:opened_at", Time.now.to_f.to_s)
      end
    end

    it 'raises CircuitOpenError without calling the block' do
      called = false
      expect do
        described_class.call(service_name) { called = true }
      end.to raise_error(CircuitBreakerService::CircuitOpenError, /#{service_name}/)
      expect(called).to be false
    end

    it 'includes the service name in the error message' do
      expect do
        described_class.call(service_name) { nil }
      end.to raise_error(CircuitBreakerService::CircuitOpenError, /#{service_name}/)
    end
  end

  describe 'half-open state (recovery window)' do
    include ActiveSupport::Testing::TimeHelpers

    before do
      # Place circuit in open state, but with an opened_at in the past so the
      # recovery timeout has elapsed.
      Sidekiq.redis do |r|
        r.call('SET', "circuit_breaker:#{service_name}:state", 'open')
        r.call(
          'SET',
          "circuit_breaker:#{service_name}:opened_at",
          (Time.now.to_f - CircuitBreakerService::RECOVERY_TIMEOUT - 1).to_s
        )
      end
    end

    it 'allows the probe request through' do
      result = described_class.call(service_name) { 'recovered' }
      expect(result).to eq('recovered')
    end

    it 'closes the circuit on a successful probe' do
      described_class.call(service_name) { 'ok' }

      state = Sidekiq.redis { |r| r.call('GET', "circuit_breaker:#{service_name}:state") }
      # After a successful recovery the state key is deleted (closed).
      expect(state).to be_nil
    end

    it 'resets failures key on a successful probe' do
      described_class.call(service_name) { 'ok' }

      failures = Sidekiq.redis { |r| r.call('GET', "circuit_breaker:#{service_name}:failures") }
      expect(failures).to be_nil
    end

    it 're-opens the circuit when the probe fails' do
      expect do
        described_class.call(service_name) { raise StandardError, 'still broken' }
      end.to raise_error(StandardError, 'still broken')

      state = Sidekiq.redis { |r| r.call('GET', "circuit_breaker:#{service_name}:state") }
      expect(state).to eq('open')
    end

    it 'updates opened_at when re-opening from half-open' do
      old_opened_at = (Time.now.to_f - CircuitBreakerService::RECOVERY_TIMEOUT - 1).to_s

      Sidekiq.redis do |r|
        r.call('SET', "circuit_breaker:#{service_name}:opened_at", old_opened_at)
      end

      expect do
        described_class.call(service_name) { raise StandardError, 'again' }
      end.to raise_error(StandardError)

      new_opened_at = Sidekiq.redis do |r|
        r.call('GET', "circuit_breaker:#{service_name}:opened_at").to_f
      end
      expect(new_opened_at).to be > old_opened_at.to_f
    end
  end

  describe 'CircuitOpenError' do
    it 'is a subclass of StandardError' do
      expect(CircuitBreakerService::CircuitOpenError.ancestors).to include(StandardError)
    end
  end
end
