# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MetaIntelligence::SyncChampionPatchStatsJob, type: :job do
  subject(:job) { described_class.new }

  # ── presence_rate formula ────────────────────────────────────────────────
  # Formula: (blue_bans + red_bans + blue_picks + red_picks) / games
  # Range:   [0, 2.0] — Oracle's Elixir event-sum convention.
  # This block guards against regressions in compute_presence_rate, which
  # briefly had a double-count bug during a linter-driven refactor (bans and
  # picks were summed before passing but the method added them again).
  describe 'presence_rate formula (compute_presence_rate)' do
    # Expose private method for white-box testing of the critical formula.
    # The alternative is integration-testing through perform(), but that
    # requires a live Scraper stub and hides the exact input values.
    let(:compute) do
      lambda do |ban_sum, pick_sum, total_games|
        job.send(:compute_presence_rate, ban_sum, pick_sum, total_games)
      end
    end

    context 'with a high-presence champion (banned + picked heavily)' do
      # Corki in a 84-game CBLOL split:
      #   blue_bans=30, red_bans=30, blue_picks=15, red_picks=15
      #   ban_sum=60, pick_sum=30
      #   (60+30)/84 = 90/84 = 1.07142...
      it 'returns the correct event-sum presence above 1.0' do
        result = compute.call(60, 30, 84)
        expect(result).to be_within(0.0001).of(1.0714)
      end

      it 'exceeds 1.0 (confirming range is [0,2.0] not [0,1])' do
        result = compute.call(60, 30, 84)
        expect(result).to be > 1.0
      end
    end

    context 'with a champion picked every game but never banned' do
      # presence = 100 picks / 100 games = 1.0 (picks only, no bans)
      it 'returns 1.0 when picked in all games' do
        result = compute.call(0, 100, 100)
        expect(result).to eq(1.0)
      end
    end

    context 'with a champion banned every game but never picked' do
      # blue_bans=50, red_bans=50 (banned both sides every game) in 100 games
      # presence = 100 / 100 = 1.0
      it 'returns 1.0 when banned both sides every game' do
        result = compute.call(100, 0, 100)
        expect(result).to eq(1.0)
      end
    end

    context 'with zero games (division guard)' do
      it 'returns nil to avoid division by zero' do
        result = compute.call(5, 5, 0)
        expect(result).to be_nil
      end
    end

    context 'with a champion absent from all games' do
      it 'returns 0.0' do
        result = compute.call(0, 0, 100)
        expect(result).to eq(0.0)
      end
    end

    context 'with pre-Season 7 data (3 bans/team = 6 total bans max)' do
      # Zed in 20 early-meta games: blue_bans=15, red_bans=10, picks=5
      # presence = (15+10+5)/20 = 30/20 = 1.5
      # Formula does NOT change for pre-S7 — ban_count_per_team is contextual only.
      it 'uses the same formula regardless of ban_count_per_team era' do
        result = compute.call(25, 5, 20)
        expect(result).to be_within(0.0001).of(1.5)
      end
    end
  end

  # ── win_rate formula ─────────────────────────────────────────────────────
  describe 'win_rate formula (compute_win_rate)' do
    let(:compute_wr) do
      lambda do |wins, pick_sum|
        job.send(:compute_win_rate, wins, pick_sum)
      end
    end

    it 'returns wins / total_picks rounded to 4 decimals' do
      expect(compute_wr.call(7, 10)).to eq(0.7)
    end

    it 'returns nil when pick_sum is zero (no appearances)' do
      expect(compute_wr.call(0, 0)).to be_nil
    end

    it 'caps at 1.0 when all picks result in wins' do
      expect(compute_wr.call(50, 50)).to eq(1.0)
    end
  end

  # ── perform integration ──────────────────────────────────────────────────
  describe '#perform' do
    let(:scraper_service) { instance_double(ProStaffScraperService) }
    let(:league) { 'CBLOL' }
    let(:patch)  { '14.10' }

    before do
      allow(ProStaffScraperService).to receive(:new).and_return(scraper_service)
    end

    context 'when the scraper returns champion data' do
      let(:scraper_response) do
        {
          'total_games' => 84,
          'champions' => [
            {
              'champion' => 'Corki',
              'role' => 'mid',
              'blue_bans' => 30,
              'red_bans' => 30,
              'blue_picks' => 15,
              'red_picks' => 15,
              'wins' => 20
            }
          ]
        }
      end

      before do
        allow(scraper_service).to receive(:fetch_champion_stats)
          .with(league: league, patch: patch, min_games: 3)
          .and_return(scraper_response)
      end

      it 'creates a ChampionPatchStat record' do
        expect do
          job.perform(league, patch)
        end.to change(ChampionPatchStat, :count).by(1)
      end

      it 'persists the correct presence_rate (event-sum, not pick-only)' do
        job.perform(league, patch)
        stat = ChampionPatchStat.find_by!(champion_name: 'Corki', league: league, patch: patch)
        # (30+30+15+15)/84 = 90/84 = 1.0714
        expect(stat.presence_rate).to be_within(0.0001).of(1.0714)
      end

      it 'persists the correct win_rate (pick-appearances only)' do
        job.perform(league, patch)
        stat = ChampionPatchStat.find_by!(champion_name: 'Corki', league: league, patch: patch)
        # 20 wins / 30 total picks = 0.6667
        expect(stat.win_rate).to be_within(0.0001).of(0.6667)
      end

      it 'is idempotent — re-running overwrites instead of duplicating' do
        job.perform(league, patch)
        expect do
          job.perform(league, patch)
        end.not_to change(ChampionPatchStat, :count)
      end

      it 'stores the role from the scraper response' do
        job.perform(league, patch)
        stat = ChampionPatchStat.find_by!(champion_name: 'Corki', league: league, patch: patch)
        expect(stat.role).to eq('mid')
      end
    end

    context 'when the scraper returns an empty champion list' do
      before do
        allow(scraper_service).to receive(:fetch_champion_stats)
          .and_return({ 'total_games' => 0, 'champions' => [] })
      end

      it 'does not create any records' do
        expect do
          job.perform(league, patch)
        end.not_to change(ChampionPatchStat, :count)
      end
    end

    context 'when the scraper is unavailable' do
      before do
        allow(scraper_service).to receive(:fetch_champion_stats)
          .and_raise(ProStaffScraperService::UnavailableError, 'timeout')
      end

      it 'raises UnavailableError for Sidekiq retry' do
        expect { job.perform(league, patch) }.to raise_error(ProStaffScraperService::UnavailableError)
      end
    end

    context 'when scraper data uses symbol keys (alternative response format)' do
      let(:symbol_key_response) do
        {
          total_games: 10,
          champions: [
            { champion: 'Azir', role: 'mid', blue_bans: 5, red_bans: 5,
              blue_picks: 3, red_picks: 3, wins: 4 }
          ]
        }
      end

      before do
        allow(scraper_service).to receive(:fetch_champion_stats)
          .and_return(symbol_key_response)
      end

      it 'handles symbol keys and persists correctly' do
        expect { job.perform(league, patch) }
          .to change(ChampionPatchStat, :count).by(1)
        stat = ChampionPatchStat.find_by!(champion_name: 'Azir')
        # (5+5+3+3)/10 = 16/10 = 1.6
        expect(stat.presence_rate).to be_within(0.0001).of(1.6)
      end
    end
  end
end
