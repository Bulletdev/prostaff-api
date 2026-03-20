# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChampionMatrixBuilder do
  let(:org) { create(:organization) }

  before do
    3.times do
      create(:competitive_match,
             organization: org,
             victory: true,
             our_picks: [
               { 'champion' => 'Jinx', 'kills' => 5, 'deaths' => 2, 'assists' => 3, 'cs' => 200, 'gold' => 12000, 'damage' => 30000, 'win' => true },
               { 'champion' => 'Thresh', 'kills' => 1, 'deaths' => 3, 'assists' => 10, 'cs' => 30, 'gold' => 8000, 'damage' => 8000, 'win' => true }
             ],
             opponent_picks: [
               { 'champion' => 'Caitlyn', 'kills' => 3, 'deaths' => 5, 'assists' => 2, 'cs' => 180, 'gold' => 10000, 'damage' => 22000, 'win' => false },
               { 'champion' => 'Lulu', 'kills' => 0, 'deaths' => 4, 'assists' => 8, 'cs' => 25, 'gold' => 7500, 'damage' => 7000, 'win' => false }
             ])
    end

    2.times do
      create(:competitive_match,
             organization: org,
             victory: false,
             our_picks: [
               { 'champion' => 'Jinx', 'kills' => 2, 'deaths' => 5, 'assists' => 1, 'cs' => 150, 'gold' => 9000, 'damage' => 18000, 'win' => false },
               { 'champion' => 'Thresh', 'kills' => 0, 'deaths' => 5, 'assists' => 4, 'cs' => 20, 'gold' => 6000, 'damage' => 5000, 'win' => false }
             ],
             opponent_picks: [
               { 'champion' => 'Caitlyn', 'kills' => 7, 'deaths' => 2, 'assists' => 3, 'cs' => 220, 'gold' => 14000, 'damage' => 35000, 'win' => true },
               { 'champion' => 'Lulu', 'kills' => 2, 'deaths' => 1, 'assists' => 12, 'cs' => 40, 'gold' => 9000, 'damage' => 9000, 'win' => true }
             ])
    end
  end

  describe '.call' do
    it 'builds matrices from our_picks and opponent_picks JSONB' do
      described_class.call
      expect(AiChampionMatrix.count).to be > 0
    end

    it 'records Jinx winning against Caitlyn 3 times' do
      described_class.call
      matrix = AiChampionMatrix.find_by('lower(champion_a) = ? AND lower(champion_b) = ?', 'jinx', 'caitlyn')
      expect(matrix).not_to be_nil
      expect(matrix.wins_a).to eq(3)
      expect(matrix.total_games).to be >= 5
    end

    it 'calculates win_rate correctly' do
      described_class.call
      matrix = AiChampionMatrix.find_by('lower(champion_a) = ? AND lower(champion_b) = ?', 'jinx', 'caitlyn')
      expect(matrix.win_rate).to be_within(0.01).of(3.0 / 5.0)
    end

    it 'clears existing data when scope is :all' do
      create(:ai_champion_matrix, champion_a: 'OldChamp', champion_b: 'OtherChamp')
      described_class.call(scope: :all)
      expect(AiChampionMatrix.find_by(champion_a: 'OldChamp')).to be_nil
    end
  end
end
