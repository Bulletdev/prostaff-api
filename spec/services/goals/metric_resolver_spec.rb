# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::MetricResolver do
  let(:org)    { create(:organization) }
  let(:player) { create(:player, organization: org) }

  def build_goal(metric_key:, **overrides)
    build(:team_goal, :evaluable, organization: org, player: player,
                                  metric_key: metric_key, **overrides)
  end

  describe '#resolve' do
    context 'when goal has no player' do
      let(:goal) { build(:team_goal, organization: org, metric_key: 'win_rate') }

      it 'returns nil' do
        expect(described_class.new(goal).resolve).to be_nil
      end
    end

    context 'when metric_key is blank' do
      let(:goal) { build(:team_goal, :for_player, organization: org, metric_key: nil) }

      it 'returns nil' do
        expect(described_class.new(goal).resolve).to be_nil
      end
    end

    context 'when metric_key is manual' do
      let(:goal) { build_goal(metric_key: 'soloq_games_week') }

      it 'returns nil without querying any source' do
        expect(described_class.new(goal).resolve).to be_nil
      end
    end

    context 'with :rails_analytics source (win_rate)' do
      let(:goal) { build_goal(metric_key: 'win_rate') }

      context 'when no matches exist' do
        it 'returns nil' do
          expect(described_class.new(goal).resolve).to be_nil
        end
      end
    end

    context 'with :rank_snapshot source (soloq_lp_total)' do
      let(:goal) { build_goal(metric_key: 'soloq_lp_total') }

      context 'when no snapshot exists' do
        it 'returns nil' do
          expect(described_class.new(goal).resolve).to be_nil
        end
      end

      context 'when a solo queue snapshot exists' do
        before do
          create(:player_rank_snapshot,
                 player: player,
                 queue_type: 'RANKED_SOLO_5x5',
                 tier: 'GOLD',
                 rank: 'II',
                 league_points: 75,
                 wins: 30,
                 losses: 20,
                 recorded_on: Date.current)
        end

        it 'returns the computed LP total (Gold II = 1200 + 200 + 75 = 1475)' do
          result = described_class.new(goal).resolve
          expect(result).to eq(1475.0)
        end
      end
    end

    context 'with :rank_snapshot source (soloq_win_rate)' do
      let(:goal) { build_goal(metric_key: 'soloq_win_rate') }

      before do
        create(:player_rank_snapshot,
               player: player,
               queue_type: 'RANKED_SOLO_5x5',
               tier: 'PLATINUM',
               rank: 'I',
               league_points: 50,
               wins: 60,
               losses: 40,
               recorded_on: Date.current)
      end

      it 'returns the win rate percentage' do
        result = described_class.new(goal).resolve
        expect(result).to eq(60.0)
      end
    end

    context 'with :scraper source (pro_kda)' do
      let(:goal) { build_goal(metric_key: 'pro_kda') }

      context 'when player has no professional_name' do
        before { player.update_columns(professional_name: nil) }

        it 'returns nil' do
          expect(described_class.new(goal).resolve).to be_nil
        end
      end

      context 'when scraper is unavailable' do
        before do
          player.update_columns(professional_name: 'Titan')
          allow_any_instance_of(ProStaffScraperService)
            .to receive(:fetch_player_profile)
            .and_raise(ProStaffScraperService::UnavailableError, 'timeout')
        end

        it 'returns nil and does not raise' do
          expect(described_class.new(goal).resolve).to be_nil
        end
      end

      context 'when scraper returns data' do
        before do
          player.update_columns(professional_name: 'Titan')
          allow_any_instance_of(ProStaffScraperService)
            .to receive(:fetch_player_profile)
            .and_return({ 'total_games' => 50, 'avg_kda' => 3.21 })
        end

        it 'returns the avg_kda from the scraper' do
          result = described_class.new(goal).resolve
          expect(result).to eq(3.21)
        end
      end
    end
  end

  describe 'LP total computation' do
    subject(:resolver) { described_class.new(build_goal(metric_key: 'soloq_lp_total')) }

    # IRON=0,BRONZE=1,SILVER=2,GOLD=3,PLATINUM=4,EMERALD=5,DIAMOND=6,MASTER=7,GM=8,CHALLENGER=9
    # total = tier_index * 400 + division_offset + lp
    [
      ['IRON',        'IV',  0,    0],
      ['IRON',        'I',  50,  350],
      ['GOLD',        'II', 75, 1475],
      ['DIAMOND',     'I',  0,  2700],
      ['MASTER',      nil,  0,  2800],
      ['CHALLENGER',  nil,  0,  3600]
    ].each do |(tier, rank, lp, expected)|
      it "computes #{tier} #{rank} #{lp}LP as #{expected}" do
        snapshot = instance_double(
          PlayerRankSnapshot,
          tier: tier, rank: rank, league_points: lp, wins: 10, losses: 5
        )
        allow(PlayerRankSnapshot).to receive_message_chain(:where, :order, :first)
          .and_return(snapshot)
        expect(resolver.resolve).to eq(expected.to_f)
      end
    end
  end
end
