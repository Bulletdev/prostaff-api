# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChampionVectorBuilder do
  let(:org) { create(:organization) }

  let(:our_picks) do
    [
      { 'champion' => 'Azir', 'kills' => 5, 'deaths' => 2, 'assists' => 3,
        'cs' => 280, 'gold' => 15000, 'damage' => 45000, 'win' => true },
      { 'champion' => 'Vi', 'kills' => 3, 'deaths' => 3, 'assists' => 8,
        'cs' => 60, 'gold' => 10000, 'damage' => 20000, 'win' => true }
    ]
  end

  let(:opponent_picks) do
    [
      { 'champion' => 'Viktor', 'kills' => 2, 'deaths' => 4, 'assists' => 1,
        'cs' => 200, 'gold' => 11000, 'damage' => 30000, 'win' => false },
      { 'champion' => 'Lee Sin', 'kills' => 1, 'deaths' => 5, 'assists' => 4,
        'cs' => 50, 'gold' => 8000, 'damage' => 12000, 'win' => false }
    ]
  end

  before do
    5.times do
      create(:competitive_match,
             organization: org,
             victory: true,
             our_picks:,
             opponent_picks:)
    end
  end

  describe '.call' do
    subject(:vector) { described_class.call(champion_name: 'Azir') }

    it 'returns a Numo::DFloat vector' do
      expect(vector).to be_a(Numo::DFloat)
    end

    it 'returns a 5-dimensional vector' do
      expect(vector.size).to eq(5)
    end

    it 'returns a normalized (unit) vector' do
      norm = Math.sqrt((vector ** 2).sum)
      expect(norm).to be_within(0.001).of(1.0)
    end

    it 'returns nil for an unknown champion' do
      expect(described_class.call(champion_name: 'UnknownChamp')).to be_nil
    end

    it 'includes a positive win_rate component for a champion who always wins' do
      expect(vector[0]).to be > 0
    end
  end

  describe '.rebuild_all!' do
    it 'creates AiChampionVector records for all champions seen' do
      described_class.rebuild_all!
      expect(AiChampionVector.count).to be >= 4
    end

    it 'stores correct games_count' do
      described_class.rebuild_all!
      azir_vector = AiChampionVector.find_by('lower(champion_name) = ?', 'azir')
      expect(azir_vector).not_to be_nil
      expect(azir_vector.games_count).to eq(5)
    end
  end
end
