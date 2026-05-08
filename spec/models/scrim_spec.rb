# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Scrim, type: :model do
  let(:org) { create(:organization) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:match).optional }
    it { should belong_to(:opponent_team).optional }
  end

  describe 'validations' do
    it 'is invalid when games_completed > games_planned' do
      scrim = build(:scrim, organization: org, games_planned: 3, games_completed: 5)
      expect(scrim).not_to be_valid
      expect(scrim.errors[:games_completed]).to be_present
    end

    it 'is valid when games_completed equals games_planned' do
      scrim = build(:scrim, :completed, organization: org)
      expect(scrim).to be_valid
    end

    it 'is invalid with negative games_planned' do
      scrim = build(:scrim, organization: org, games_planned: -1)
      expect(scrim).not_to be_valid
    end
  end

  describe '#status' do
    it 'returns upcoming for a future scrim with no games completed' do
      scrim = build(:scrim, organization: org, scheduled_at: 2.days.from_now)
      expect(scrim.status).to eq('upcoming')
    end

    it 'returns completed when games_completed >= games_planned' do
      scrim = create(:scrim, :completed, :past, organization: org)
      expect(scrim.status).to eq('completed')
    end

    it 'returns in_progress when some but not all games completed' do
      scrim = create(:scrim, :past, organization: org, games_planned: 3, games_completed: 1)
      expect(scrim.status).to eq('in_progress')
    end
  end

  describe '#win_rate' do
    it 'returns 0 when game_results is empty' do
      scrim = build(:scrim, organization: org, game_results: [])
      expect(scrim.win_rate).to eq(0)
    end

    it 'calculates win_rate within [0, 100]' do
      scrim = build(:scrim, organization: org, game_results: [
                      { 'victory' => true }, { 'victory' => true }, { 'victory' => false }
                    ])
      expect(scrim.win_rate).to be_between(0, 100)
    end

    it 'returns 100 when all games are victories' do
      scrim = build(:scrim, organization: org, game_results: [
                      { 'victory' => true }, { 'victory' => true }
                    ])
      expect(scrim.win_rate).to eq(100.0)
    end
  end

  describe '#add_game_result' do
    let(:scrim) { create(:scrim, organization: org, games_planned: 3, games_completed: 0, game_results: []) }

    it 'appends a new game result' do
      expect { scrim.add_game_result(victory: true) }
        .to change { scrim.game_results.size }.by(1)
    end

    it 'increments games_completed' do
      expect { scrim.add_game_result(victory: false) }
        .to change { scrim.games_completed }.by(1)
    end

    it 'records the victory flag correctly' do
      scrim.add_game_result(victory: true)
      expect(scrim.game_results.last['victory']).to be true
    end
  end

  describe '#completion_percentage' do
    it 'returns 0 when games_planned is nil' do
      scrim = build(:scrim, organization: org, games_planned: nil)
      expect(scrim.completion_percentage).to eq(0)
    end

    it 'returns 100 when all games are completed' do
      scrim = build(:scrim, :completed, organization: org)
      expect(scrim.completion_percentage).to eq(100.0)
    end
  end
end
