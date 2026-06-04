# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PerformanceAnalyticsService, type: :service do
  let(:organization) { create(:organization) }

  # OrganizationScoped default_scope filters out records when Current.organization_id is nil.
  # Set it for the duration of each example so Match, Player, and related queries work.
  before do
    Current.organization_id = organization.id
  end

  after do
    Current.reset
  end

  let(:players) do
    %w[top jungle mid adc support].map do |role|
      create(:player, organization: organization, role: role)
    end
  end

  let(:matches_scope) { Match.where(organization: organization) }
  let(:players_scope) { Player.where(organization: organization) }

  subject(:service) { described_class.new(matches_scope, players_scope) }

  # ---------------------------------------------------------------------------
  # Edge case: no matches
  # ---------------------------------------------------------------------------

  describe '#calculate_performance_data with no matches' do
    it 'returns a hash without raising' do
      expect { service.calculate_performance_data }.not_to raise_error
    end

    it 'returns overview with total_matches == 0 (not an error)' do
      result = service.calculate_performance_data
      # With no matches the service still returns a complete overview hash with zeros
      expect(result[:overview]).to be_a(Hash)
      expect(result[:overview][:total_matches]).to eq(0)
    end

    it 'returns win_rate_trend as empty array' do
      result = service.calculate_performance_data
      expect(result[:win_rate_trend]).to eq([])
    end

    it 'returns best_performers as empty array' do
      result = service.calculate_performance_data
      expect(result[:best_performers]).to eq([])
    end

    it 'returns performance_by_role as empty array' do
      result = service.calculate_performance_data
      expect(result[:performance_by_role]).to eq([])
    end
  end

  # ---------------------------------------------------------------------------
  # Edge case: single match
  # ---------------------------------------------------------------------------

  describe '#calculate_performance_data with a single match' do
    let!(:match) do
      create(:match, organization: organization, victory: true, game_start: 1.day.ago)
    end

    before do
      players.each do |p|
        create(:player_match_stat, match: match, player: p,
               kills: 4, deaths: 2, assists: 6)
      end
    end

    it 'returns overview with total_matches == 1' do
      result = service.calculate_performance_data
      expect(result[:overview][:total_matches]).to eq(1)
    end

    it 'returns win_rate == 100.0 when the single match is a win' do
      result = service.calculate_performance_data
      expect(result[:overview][:win_rate]).to eq(100.0)
    end

    it 'returns avg_kda >= 0' do
      result = service.calculate_performance_data
      expect(result[:overview][:avg_kda]).to be >= 0
    end

    it 'returns wins + losses == total_matches' do
      result = service.calculate_performance_data
      ov = result[:overview]
      expect(ov[:wins] + ov[:losses]).to eq(ov[:total_matches])
    end
  end

  # ---------------------------------------------------------------------------
  # Team overview — domain invariants
  # ---------------------------------------------------------------------------

  describe '#calculate_performance_data team overview invariants' do
    before do
      create_list(:match, 7, organization: organization, victory: true)
      create_list(:match, 3, organization: organization, victory: false)

      Match.where(organization: organization).each do |m|
        players.each do |p|
          create(:player_match_stat, match: m, player: p,
                 kills: rand(3..8), deaths: rand(1..5), assists: rand(4..12))
        end
      end
    end

    it 'returns win_rate within [0, 100]' do
      result = service.calculate_performance_data
      expect(result[:overview][:win_rate]).to be_between(0, 100)
    end

    it 'returns win_rate == 70.0 with 7 wins out of 10' do
      result = service.calculate_performance_data
      expect(result[:overview][:win_rate]).to eq(70.0)
    end

    it 'returns avg_kda >= 0' do
      result = service.calculate_performance_data
      expect(result[:overview][:avg_kda]).to be >= 0
    end

    it 'returns avg_kills_per_game >= 0' do
      result = service.calculate_performance_data
      expect(result[:overview][:avg_kills_per_game]).to be >= 0
    end

    it 'returns avg_deaths_per_game >= 0' do
      result = service.calculate_performance_data
      expect(result[:overview][:avg_deaths_per_game]).to be >= 0
    end

    it 'returns avg_assists_per_game >= 0' do
      result = service.calculate_performance_data
      expect(result[:overview][:avg_assists_per_game]).to be >= 0
    end

    it 'returns total_matches == 10' do
      result = service.calculate_performance_data
      expect(result[:overview][:total_matches]).to eq(10)
    end
  end

  # ---------------------------------------------------------------------------
  # Edge case: all deaths == 0 (KDA division-by-zero guard)
  # ---------------------------------------------------------------------------

  describe '#calculate_performance_data with all zero-death stats' do
    let!(:match) { create(:match, organization: organization, victory: true, game_start: 1.day.ago) }

    before do
      players.each do |p|
        create(:player_match_stat, match: match, player: p,
               kills: 8, deaths: 0, assists: 12)
      end
    end

    it 'returns avg_kda >= 0 without raising ZeroDivisionError' do
      expect { service.calculate_performance_data }.not_to raise_error
      result = service.calculate_performance_data
      expect(result[:overview][:avg_kda]).to be >= 0
    end
  end

  # ---------------------------------------------------------------------------
  # win_rate_trend sorted ASC
  # ---------------------------------------------------------------------------

  describe '#calculate_performance_data win_rate_trend ordering' do
    include ActiveSupport::Testing::TimeHelpers

    before do
      [4.weeks.ago, 3.weeks.ago, 2.weeks.ago, 1.week.ago].each_with_index do |date, i|
        m = create(:match, organization: organization, victory: i.even?, game_start: date)
        players.first(2).each do |p|
          create(:player_match_stat, match: m, player: p,
                 kills: 3, deaths: 2, assists: 5)
        end
      end
    end

    it 'returns win_rate_trend sorted by period ascending' do
      result = service.calculate_performance_data
      trend = result[:win_rate_trend]
      periods = trend.map { |d| d[:period] }
      expect(periods).to eq(periods.sort)
    end

    it 'returns win_rate within [0, 100] for each trend period' do
      result = service.calculate_performance_data
      result[:win_rate_trend].each do |period|
        expect(period[:win_rate]).to be_between(0, 100)
      end
    end

    it 'returns wins + losses == matches for each trend period' do
      result = service.calculate_performance_data
      result[:win_rate_trend].each do |period|
        expect(period[:wins] + period[:losses]).to eq(period[:matches])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # best_performers
  # ---------------------------------------------------------------------------

  describe '#calculate_performance_data best_performers' do
    before do
      3.times do |i|
        m = create(:match, organization: organization, victory: i.zero?,
                            game_start: (i + 1).days.ago)
        players.each do |p|
          create(:player_match_stat, match: m, player: p,
                 kills: rand(3..8), deaths: rand(1..4), assists: rand(4..10),
                 performance_score: rand(60..95))
        end
      end
    end

    it 'returns at most 5 best performers' do
      result = service.calculate_performance_data
      expect(result[:best_performers].size).to be <= 5
    end

    it 'returns avg_kda >= 0 for every performer' do
      result = service.calculate_performance_data
      result[:best_performers].each do |perf|
        expect(perf[:avg_kda]).to be >= 0,
          "avg_kda #{perf[:avg_kda]} is negative for #{perf.dig(:player, :summoner_name)}"
      end
    end

    it 'returns games > 0 for every performer' do
      result = service.calculate_performance_data
      result[:best_performers].each do |perf|
        expect(perf[:games]).to be > 0
      end
    end

    it 'returns a player hash with summoner_name for each performer' do
      result = service.calculate_performance_data
      result[:best_performers].each do |perf|
        expect(perf[:player]).to be_present
        expect(perf[:player][:summoner_name]).to be_present
      end
    end
  end

  # ---------------------------------------------------------------------------
  # player_statistics (individual lookup)
  # ---------------------------------------------------------------------------

  describe '#calculate_performance_data with player_id' do
    let(:mid_player) { create(:player, organization: organization, role: 'mid') }

    context 'when player has no stats in the matches' do
      it 'returns player_stats as nil' do
        result = service.calculate_performance_data(player_id: mid_player.id)
        expect(result[:player_stats]).to be_nil
      end
    end

    context 'when player has stats' do
      before do
        2.times do |i|
          m = create(:match, organization: organization, victory: i.zero?,
                              game_start: (i + 1).days.ago)
          create(:player_match_stat, match: m, player: mid_player,
                 kills: 5, deaths: 1, assists: 8)
        end
      end

      it 'skips team-level aggregations (returns empty overview hash)' do
        result = service.calculate_performance_data(player_id: mid_player.id)
        expect(result[:overview]).to eq({})
      end

      it 'returns non-nil player_stats' do
        result = service.calculate_performance_data(player_id: mid_player.id)
        expect(result[:player_stats]).to be_present
      end

      it 'returns player_stats with games_played > 0' do
        result = service.calculate_performance_data(player_id: mid_player.id)
        expect(result[:player_stats][:games_played]).to be > 0
      end

      it 'returns player_stats kda >= 0' do
        result = service.calculate_performance_data(player_id: mid_player.id)
        expect(result[:player_stats][:kda]).to be >= 0
      end

      it 'returns player_stats win_rate within [0, 1] (raw fraction)' do
        result = service.calculate_performance_data(player_id: mid_player.id)
        expect(result[:player_stats][:win_rate]).to be_between(0, 1)
      end
    end

    context 'when player_id does not exist in the scope' do
      it 'returns player_stats as nil' do
        result = service.calculate_performance_data(player_id: 0)
        expect(result[:player_stats]).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edge case: 100 matches
  # ---------------------------------------------------------------------------

  describe '#calculate_performance_data with 100 matches' do
    before do
      100.times do |i|
        m = create(:match, organization: organization, victory: i < 60,
                            game_start: (100 - i).days.ago)
        players.first(2).each do |p|
          create(:player_match_stat, match: m, player: p,
                 kills: rand(0..15), deaths: rand(0..10), assists: rand(0..20))
        end
      end
    end

    it 'returns total_matches == 100' do
      result = service.calculate_performance_data
      expect(result[:overview][:total_matches]).to eq(100)
    end

    it 'returns win_rate within [0, 100]' do
      result = service.calculate_performance_data
      expect(result[:overview][:win_rate]).to be_between(0, 100)
    end

    it 'returns avg_kda >= 0 with all data' do
      result = service.calculate_performance_data
      expect(result[:overview][:avg_kda]).to be >= 0
    end
  end
end
