# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiRecommendationService do
  let(:our_picks)      { %w[Jinx Thresh Azir Vi] }
  let(:opponent_picks) { %w[Caitlyn Lulu Viktor LeeSin] }
  let(:our_bans)       { %w[Zed] }
  let(:opponent_bans)  { %w[Syndra] }
  let(:patch)          { '16.08' }
  let(:league)         { 'LCK' }

  let(:ml_success_response) do
    {
      source: 'ml_v2',
      model_version: 'v2',
      recommendations: [
        {
          champion: 'Garen',
          score: 0.78,
          win_probability: 0.62,
          synergy_score: 0.71,
          counter_score: 0.65,
          reasoning_tokens: ['top_open', 'synergizes_with_jinx']
        }
      ]
    }
  end

  let(:legacy_suggestions) { %w[Garen Malphite] }

  before do
    allow(PredictionLogger).to receive(:log)
    allow(DraftSuggester).to receive(:call).and_return(legacy_suggestions)
  end

  def build_service(extra_args = {})
    described_class.new(
      our_picks:      our_picks,
      opponent_picks: opponent_picks,
      our_bans:       our_bans,
      opponent_bans:  opponent_bans,
      patch:          patch,
      league:         league,
      **extra_args
    )
  end

  # ---------------------------------------------------------------------------
  # build_payload — accessed via send to verify the private method directly
  # ---------------------------------------------------------------------------
  describe '#build_payload (via send)' do
    context 'when role_needed is provided' do
      it 'includes role_needed with the given value' do
        service = build_service(role_needed: 'mid')
        payload = service.send(:build_payload)

        expect(payload).to include(role_needed: 'mid')
      end
    end

    context 'when role_needed is omitted (defaults to nil)' do
      it 'includes role_needed key with nil value' do
        service = build_service
        payload = service.send(:build_payload)

        expect(payload).to have_key(:role_needed)
        expect(payload[:role_needed]).to be_nil
      end
    end

    context 'when role_needed is an empty string' do
      it 'includes role_needed with empty string without conversion' do
        service = build_service(role_needed: '')
        payload = service.send(:build_payload)

        expect(payload).to include(role_needed: '')
      end
    end

    it 'includes all expected keys' do
      service = build_service(role_needed: 'top')
      payload = service.send(:build_payload)

      expect(payload.keys).to match_array(
        %i[our_picks opponent_picks our_bans opponent_bans patch league role_needed]
      )
    end
  end

  # ---------------------------------------------------------------------------
  # ML service propagation
  # ---------------------------------------------------------------------------
  describe 'role_needed propagation to ML service' do
    context 'with role_needed: "mid"' do
      it 'sends role_needed: "mid" in the payload to MlServiceClient' do
        allow(MlServiceClient).to receive(:post).and_return(ml_success_response)

        build_service(role_needed: 'mid').call

        expect(MlServiceClient).to have_received(:post) do |_path, payload, **_opts|
          expect(payload[:role_needed]).to eq('mid')
        end
      end
    end

    context 'with role_needed: nil (omitted)' do
      it 'sends role_needed: nil in the payload to MlServiceClient' do
        allow(MlServiceClient).to receive(:post).and_return(ml_success_response)

        build_service.call

        expect(MlServiceClient).to have_received(:post) do |_path, payload, **_opts|
          expect(payload[:role_needed]).to be_nil
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Fallback behaviour
  # ---------------------------------------------------------------------------
  describe '#call — fallback on ML failure' do
    shared_examples 'graceful legacy fallback' do
      it 'returns source: "legacy" without raising' do
        expect { result }.not_to raise_error
        expect(result[:source]).to eq('legacy')
      end

      it 'calls DraftSuggester with our_picks as team_a and combined bans' do
        result

        expect(DraftSuggester).to have_received(:call).with(
          team_a: our_picks,
          team_b: opponent_picks,
          bans: our_bans + opponent_bans
        )
      end

      it 'maps DraftSuggester output into the recommendations array' do
        expect(result[:recommendations].map { |r| r[:champion] }).to eq(legacy_suggestions)
      end

      it 'sets model_version to nil in the fallback response' do
        expect(result[:model_version]).to be_nil
      end

      it 'sets score, win_probability, synergy_score, counter_score to nil per recommendation' do
        result[:recommendations].each do |rec|
          expect(rec[:score]).to be_nil
          expect(rec[:win_probability]).to be_nil
          expect(rec[:synergy_score]).to be_nil
          expect(rec[:counter_score]).to be_nil
        end
      end

      it 'sets reasoning_tokens to an empty array per recommendation' do
        result[:recommendations].each do |rec|
          expect(rec[:reasoning_tokens]).to eq([])
        end
      end

      it 'does not call PredictionLogger' do
        result
        expect(PredictionLogger).not_to have_received(:log)
      end
    end

    context 'when MlServiceClient raises MlCircuitOpenError' do
      let(:result) do
        allow(MlServiceClient).to receive(:post)
          .and_raise(MlServiceClient::MlCircuitOpenError, 'circuit open')
        build_service.call
      end

      include_examples 'graceful legacy fallback'
    end

    context 'when MlServiceClient raises MlServiceDisabledError' do
      let(:result) do
        allow(MlServiceClient).to receive(:post)
          .and_raise(MlServiceClient::MlServiceDisabledError, 'kill switch active')
        build_service.call
      end

      include_examples 'graceful legacy fallback'
    end

    context 'when MlServiceClient raises MlServiceError (invalid JSON / non-2xx)' do
      let(:result) do
        allow(MlServiceClient).to receive(:post)
          .and_raise(MlServiceClient::MlServiceError, 'invalid JSON response')
        build_service.call
      end

      include_examples 'graceful legacy fallback'
    end
  end

  # ---------------------------------------------------------------------------
  # Happy path
  # ---------------------------------------------------------------------------
  describe '#call — ML success path' do
    before do
      allow(MlServiceClient).to receive(:post).and_return(ml_success_response)
    end

    it 'returns source: "ml_v2"' do
      result = build_service.call
      expect(result[:source]).to eq('ml_v2')
    end

    it 'returns the model_version from the ML response' do
      result = build_service.call
      expect(result[:model_version]).to eq('v2')
    end

    it 'returns the recommendations array from the ML response' do
      result = build_service.call
      expect(result[:recommendations]).to be_an(Array)
      expect(result[:recommendations].first[:champion]).to eq('Garen')
    end

    it 'calls PredictionLogger with the correct source' do
      build_service.call
      expect(PredictionLogger).to have_received(:log).with(
        hash_including(source: 'ml_v2', patch: patch, league: league)
      )
    end
  end
end
