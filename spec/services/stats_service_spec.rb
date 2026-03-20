# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StatsService do
  let(:org)    { create(:organization) }
  let(:player) { create(:player, organization: org) }

  # ---------------------------------------------------------------------------
  # .calculate_win_rate
  # ---------------------------------------------------------------------------

  describe '.calculate_win_rate' do
    it 'returns 0 for an empty relation' do
      expect(described_class.calculate_win_rate(Match.none)).to eq(0)
    end

    it 'returns 100.0 when all matches are victories' do
      create_list(:match, 3, organization: org, victory: true)
      matches = Match.unscoped.where(organization: org)
      expect(described_class.calculate_win_rate(matches)).to eq(100.0)
    end

    it 'returns 0.0 when all matches are losses' do
      create_list(:match, 3, organization: org, victory: false)
      matches = Match.unscoped.where(organization: org)
      expect(described_class.calculate_win_rate(matches)).to eq(0.0)
    end

    it 'calculates a correct 60% win rate' do
      create_list(:match, 6, organization: org, victory: true)
      create_list(:match, 4, organization: org, victory: false)
      matches = Match.unscoped.where(organization: org)
      expect(described_class.calculate_win_rate(matches)).to eq(60.0)
    end

    it 'always returns a value within [0, 100]' do
      create_list(:match, 5, organization: org)
      matches = Match.unscoped.where(organization: org)
      result = described_class.calculate_win_rate(matches)
      expect(result).to be_between(0, 100)
    end
  end

  # ---------------------------------------------------------------------------
  # .calculate_avg_kda
  # ---------------------------------------------------------------------------

  describe '.calculate_avg_kda' do
    it 'returns 0 for empty stats' do
      expect(described_class.calculate_avg_kda(PlayerMatchStat.none)).to eq(0)
    end

    it 'never returns a negative value' do
      match = create(:match, organization: org)
      create(:player_match_stat, player: player, match: match, kills: 0, deaths: 10, assists: 0)
      stats = PlayerMatchStat.unscoped.where(player: player)
      expect(described_class.calculate_avg_kda(stats)).to be >= 0
    end

    it 'handles deaths=0 without dividing by zero' do
      match = create(:match, organization: org)
      create(:player_match_stat, player: player, match: match, kills: 5, deaths: 0, assists: 10)
      stats = PlayerMatchStat.unscoped.where(player: player)
      expect { described_class.calculate_avg_kda(stats) }.not_to raise_error
      expect(described_class.calculate_avg_kda(stats)).to be >= 0
    end

    it 'calculates KDA correctly when deaths > 0' do
      match = create(:match, organization: org)
      # KDA = (kills + assists) / deaths = (4 + 8) / 4 = 3.0
      create(:player_match_stat, player: player, match: match, kills: 4, deaths: 4, assists: 8)
      stats = PlayerMatchStat.unscoped.where(player: player)
      expect(described_class.calculate_avg_kda(stats)).to eq(3.0)
    end
  end

  # ---------------------------------------------------------------------------
  # .calculate_recent_form
  # ---------------------------------------------------------------------------

  describe '.calculate_recent_form' do
    it 'returns empty array for no matches' do
      expect(described_class.calculate_recent_form(Match.none)).to eq([])
    end

    it 'returns W for victories and L for defeats' do
      victories = Array.new(2) { create(:match, organization: org, victory: true) }
      defeats   = Array.new(1) { create(:match, organization: org, victory: false) }
      matches   = Match.unscoped.where(id: victories.map(&:id) + defeats.map(&:id))
      result    = described_class.calculate_recent_form(matches)
      expect(result.count('W')).to eq(2)
      expect(result.count('L')).to eq(1)
    end

    it 'only contains W or L characters' do
      create_list(:match, 5, organization: org)
      matches = Match.unscoped.where(organization: org)
      result = described_class.calculate_recent_form(matches)
      expect(result).to all(match(/\A[WL]\z/))
    end
  end

  # ---------------------------------------------------------------------------
  # #calculate_stats
  # ---------------------------------------------------------------------------

  describe '#calculate_stats' do
    subject(:service) { described_class.new(player) }

    it 'returns a hash with all expected top-level keys' do
      result = service.calculate_stats
      expect(result).to include(:player, :overall, :recent_form, :champion_pool, :performance_by_role)
    end

    it 'returns the correct player' do
      result = service.calculate_stats
      expect(result[:player]).to eq(player)
    end

    it 'returns overall win_rate within [0, 100]' do
      create_list(:match, 3, organization: org, victory: true) # rubocop:disable RSpec/LetSetup
      result = service.calculate_stats
      expect(result[:overall][:win_rate]).to be_between(0, 100)
    end

    it 'returns overall avg_kda >= 0' do
      result = service.calculate_stats
      expect(result[:overall][:avg_kda]).to be >= 0
    end
  end
end
