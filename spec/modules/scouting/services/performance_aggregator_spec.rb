# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PerformanceAggregator do
  let(:riot_service) { instance_double('RiotApiService') }
  subject(:aggregator) { described_class.new(riot_service: riot_service) }

  # Sample participant hashes matching what RiotApiService returns
  def participant(overrides = {})
    {
      puuid: 'target-puuid-123',
      champion_name: 'Jinx',
      kills: 5,
      deaths: 2,
      assists: 8,
      win: true,
      vision_score: 30,
      minions_killed: 180,
      neutral_minions_killed: 20
    }.merge(overrides)
  end

  let(:puuid)  { 'target-puuid-123' }
  let(:region) { 'BR' }

  describe '#call' do
    # ── Nil/blank PUUID guard ──────────────────────────────────────────────

    context 'when puuid is blank' do
      it 'returns nil without calling the riot service' do
        expect(riot_service).not_to receive(:get_match_history)
        result = aggregator.call(puuid: '', region: region)
        expect(result).to be_nil
      end

      it 'handles nil puuid without raising' do
        expect(riot_service).not_to receive(:get_match_history)
        result = aggregator.call(puuid: nil, region: region)
        expect(result).to be_nil
      end
    end

    # ── No match history ──────────────────────────────────────────────────

    context 'when get_match_history returns empty array' do
      before do
        allow(riot_service).to receive(:get_match_history)
          .with(puuid: puuid, region: region, count: PerformanceAggregator::MATCH_COUNT)
          .and_return([])
      end

      it 'returns nil (not empty hash, not exception)' do
        result = aggregator.call(puuid: puuid, region: region)
        expect(result).to be_nil
      end
    end

    # ── No participant data found for target's PUUID ──────────────────────

    context 'when match details have no participant with matching PUUID' do
      before do
        allow(riot_service).to receive(:get_match_history)
          .and_return(['BR1_111111'])

        allow(riot_service).to receive(:get_match_details)
          .with(match_id: 'BR1_111111', region: region)
          .and_return({ participants: [participant(puuid: 'other-puuid')] })
      end

      it 'returns nil' do
        result = aggregator.call(puuid: puuid, region: region)
        expect(result).to be_nil
      end
    end

    # ── Normal case with multiple matches ─────────────────────────────────

    context 'with 3 valid matches' do
      let(:match_ids) { %w[BR1_001 BR1_002 BR1_003] }

      let(:match_data) do
        {
          'BR1_001' => { participants: [participant(kills: 10, deaths: 2, assists: 5, win: true, champion_name: 'Jinx')] },
          'BR1_002' => { participants: [participant(kills: 3,  deaths: 4, assists: 7, win: false, champion_name: 'Caitlyn')] },
          'BR1_003' => { participants: [participant(kills: 6,  deaths: 0, assists: 9, win: true, champion_name: 'Jinx')] }
        }
      end

      before do
        allow(riot_service).to receive(:get_match_history)
          .with(puuid: puuid, region: region, count: PerformanceAggregator::MATCH_COUNT)
          .and_return(match_ids)

        match_ids.each do |id|
          allow(riot_service).to receive(:get_match_details)
            .with(match_id: id, region: region)
            .and_return(match_data[id])
        end
      end

      it 'returns a hash (not nil)' do
        result = aggregator.call(puuid: puuid, region: region)
        expect(result).to be_a(Hash)
      end

      it 'sets games_played to 3' do
        result = aggregator.call(puuid: puuid, region: region)
        expect(result[:games_played]).to eq(3)
      end

      it 'sets matches_analyzed to 3' do
        result = aggregator.call(puuid: puuid, region: region)
        expect(result[:matches_analyzed]).to eq(3)
      end

      it 'win_rate is between 0 and 100 (2 wins out of 3 = ~66.7)' do
        result = aggregator.call(puuid: puuid, region: region)
        expect(result[:win_rate]).to be_between(0.0, 100.0)
        expect(result[:win_rate]).to be_within(0.2).of(66.7)
      end

      it 'avg_kda is >= 0 (never negative)' do
        result = aggregator.call(puuid: puuid, region: region)
        expect(result[:avg_kda]).to be >= 0
      end

      it 'avg_kda handles deaths == 0 without dividing by zero' do
        # BR1_003 has deaths: 0 — KDA for that game is kills + assists
        result = aggregator.call(puuid: puuid, region: region)
        expect(result[:avg_kda]).to be_a(Float)
        expect(result[:avg_kda]).to be >= 0
      end

      it 'avg_kills, avg_deaths, avg_assists are non-negative' do
        result = aggregator.call(puuid: puuid, region: region)
        expect(result[:avg_kills]).to be >= 0
        expect(result[:avg_deaths]).to be >= 0
        expect(result[:avg_assists]).to be >= 0
      end

      it 'includes champion_pool_stats as an array' do
        result = aggregator.call(puuid: puuid, region: region)
        expect(result[:champion_pool_stats]).to be_an(Array)
      end

      it 'champion_pool_stats sorted by games descending' do
        result = aggregator.call(puuid: puuid, region: region)
        games_counts = result[:champion_pool_stats].map { |c| c[:games] }
        expect(games_counts).to eq(games_counts.sort.reverse)
      end

      it 'each champion entry has expected keys' do
        result = aggregator.call(puuid: puuid, region: region)
        entry = result[:champion_pool_stats].first
        expect(entry).to include(:champion, :games, :wins, :winrate, :kda_ratio,
                                 :avg_kills, :avg_deaths, :avg_assists, :avg_cs_per_min)
      end

      it 'champion winrate is between 0 and 100' do
        result = aggregator.call(puuid: puuid, region: region)
        result[:champion_pool_stats].each do |champ|
          expect(champ[:winrate]).to be_between(0.0, 100.0)
        end
      end

      it 'champion kda_ratio is >= 0' do
        result = aggregator.call(puuid: puuid, region: region)
        result[:champion_pool_stats].each do |champ|
          expect(champ[:kda_ratio]).to be >= 0
        end
      end
    end

    # ── Deaths == 0 across all games: KDA must be kills + assists ─────────

    context 'when target has 0 deaths in every match' do
      before do
        allow(riot_service).to receive(:get_match_history)
          .and_return(['BR1_DEATHLESS'])

        allow(riot_service).to receive(:get_match_details)
          .with(match_id: 'BR1_DEATHLESS', region: region)
          .and_return({
                        participants: [participant(kills: 8, deaths: 0, assists: 12, win: true)]
                      })
      end

      it 'returns avg_kda equal to (kills + assists) / total — never negative' do
        result = aggregator.call(puuid: puuid, region: region)
        # kda_ratio(8, 0, 12, 1) => (8+12).to_f / 1 = 20.0
        expect(result[:avg_kda]).to eq(20.0)
        expect(result[:avg_kda]).to be >= 0
      end
    end

    # ── RiotApiError on match history call ────────────────────────────────

    context 'when get_match_history raises RiotApiService::RiotApiError' do
      before do
        allow(riot_service).to receive(:get_match_history)
          .and_raise(RiotApiService::RiotApiError.new('Service unavailable'))
      end

      it 'returns nil without raising' do
        expect { aggregator.call(puuid: puuid, region: region) }.not_to raise_error
        result = aggregator.call(puuid: puuid, region: region)
        expect(result).to be_nil
      end
    end

    # ── RiotApiError on individual match detail: skipped gracefully ────────

    context 'when one match detail raises RiotApiService::RiotApiError' do
      before do
        allow(riot_service).to receive(:get_match_history)
          .and_return(%w[BR1_OK BR1_FAIL])

        allow(riot_service).to receive(:get_match_details)
          .with(match_id: 'BR1_OK', region: region)
          .and_return({ participants: [participant] })

        allow(riot_service).to receive(:get_match_details)
          .with(match_id: 'BR1_FAIL', region: region)
          .and_raise(RiotApiService::RiotApiError.new('Not found'))
      end

      it 'returns aggregated data from the successful match only' do
        result = aggregator.call(puuid: puuid, region: region)
        expect(result).not_to be_nil
        expect(result[:games_played]).to eq(1)
      end
    end
  end
end
