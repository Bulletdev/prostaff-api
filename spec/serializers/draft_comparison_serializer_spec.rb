# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DraftComparisonSerializer do
  let(:comparison_data) do
    {
      similarity_score: 78.5,
      composition_winrate: 54.2,
      meta_score: 82.0,
      insights: ['Strong early game', 'Weak in teamfights'],
      patch: '14.12',
      analyzed_at: Time.current,
      similar_matches: [
        { id: 1, tournament: 'CBLOL', victory: true },
        { id: 2, tournament: 'LCK', victory: false }
      ]
    }
  end

  # DraftComparisonSerializer operates on a hash (not an AR model)
  subject(:result) { described_class.render_as_hash(comparison_data) }

  it 'exposes similarity_score' do
    expect(result[:similarity_score]).to eq(78.5)
  end

  it 'exposes composition_winrate' do
    expect(result[:composition_winrate]).to eq(54.2)
  end

  it 'exposes meta_score' do
    expect(result[:meta_score]).to eq(82.0)
  end

  it 'exposes insights' do
    expect(result[:insights]).to be_an(Array)
    expect(result[:insights]).not_to be_empty
  end

  it 'exposes patch' do
    expect(result[:patch]).to eq('14.12')
  end

  it 'exposes analyzed_at' do
    expect(result[:analyzed_at]).to be_present
  end

  describe 'similar_matches field' do
    it 'is an array' do
      expect(result[:similar_matches]).to be_an(Array)
    end

    it 'has the correct count' do
      expect(result[:similar_matches].size).to eq(2)
    end
  end

  describe 'summary field' do
    it 'is a hash' do
      expect(result[:summary]).to be_a(Hash)
    end

    it 'includes total_similar_matches' do
      expect(result[:summary][:total_similar_matches]).to eq(2)
    end

    it 'includes avg_similarity' do
      expect(result[:summary][:avg_similarity]).to eq(78.5)
    end

    it 'includes meta_alignment' do
      expect(result[:summary][:meta_alignment]).to eq(82.0)
    end

    it 'includes expected_winrate' do
      expect(result[:summary][:expected_winrate]).to eq(54.2)
    end
  end

  describe 'with no similar matches' do
    let(:comparison_data) do
      {
        similarity_score: 0.0,
        composition_winrate: 0.0,
        meta_score: 0.0,
        insights: [],
        patch: '14.12',
        analyzed_at: Time.current,
        similar_matches: []
      }
    end

    it 'has total_similar_matches of 0' do
      expect(result[:summary][:total_similar_matches]).to eq(0)
    end
  end
end
