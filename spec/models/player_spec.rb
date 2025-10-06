require 'rails_helper'

RSpec.describe Player, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should have_many(:player_match_stats).dependent(:destroy) }
    it { should have_many(:matches).through(:player_match_stats) }
    it { should have_many(:champion_pools).dependent(:destroy) }
    it { should have_many(:team_goals).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:summoner_name) }
    it { should validate_length_of(:summoner_name).is_at_most(100) }
    it { should validate_presence_of(:role) }
    it { should validate_inclusion_of(:role).in_array(%w[top jungle mid adc support]) }
    it { should validate_inclusion_of(:status).in_array(%w[active inactive benched trial]) }
  end

  describe 'instance methods' do
    let(:player) { create(:player, solo_queue_tier: 'CHALLENGER', solo_queue_rank: 'I', solo_queue_lp: 500) }

    describe '#current_rank_display' do
      it 'returns formatted rank' do
        expect(player.current_rank_display).to eq('Challenger I (500 LP)')
      end

      it 'returns Unranked for unranked player' do
        player.update(solo_queue_tier: nil)
        expect(player.current_rank_display).to eq('Unranked')
      end
    end

    describe '#win_rate' do
      it 'calculates win rate correctly' do
        player.update(solo_queue_wins: 60, solo_queue_losses: 40)
        expect(player.win_rate).to eq(60.0)
      end

      it 'returns 0 for no games' do
        player.update(solo_queue_wins: 0, solo_queue_losses: 0)
        expect(player.win_rate).to eq(0)
      end
    end

    describe '#age' do
      it 'calculates age from birth date' do
        player.update(birth_date: 20.years.ago)
        expect(player.age).to eq(20)
      end

      it 'returns nil when no birth date' do
        player.update(birth_date: nil)
        expect(player.age).to be_nil
      end
    end
  end

  describe 'scopes' do
    let(:organization) { create(:organization) }
    let!(:active_player) { create(:player, status: 'active', organization: organization) }
    let!(:benched_player) { create(:player, status: 'benched', organization: organization) }

    describe '.active' do
      it 'returns only active players' do
        expect(Player.active).to include(active_player)
        expect(Player.active).not_to include(benched_player)
      end
    end

    describe '.by_role' do
      let!(:mid_player) { create(:player, role: 'mid', organization: organization) }

      it 'filters players by role' do
        expect(Player.by_role('mid')).to include(mid_player)
      end
    end
  end
end
