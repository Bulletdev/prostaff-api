require 'rails_helper'

RSpec.describe Match, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should have_many(:player_match_stats).dependent(:destroy) }
    it { should have_many(:players).through(:player_match_stats) }
    it { should have_many(:vod_reviews).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:match_type) }
    it { should validate_inclusion_of(:match_type).in_array(%w[official scrim tournament]) }
    it { should validate_inclusion_of(:our_side).in_array(%w[blue red]).allow_nil }
  end

  describe 'instance methods' do
    let(:match) { create(:match, victory: true, game_duration: 1800) }

    describe '#result_text' do
      it 'returns Victory for won match' do
        expect(match.result_text).to eq('Victory')
      end

      it 'returns Defeat for lost match' do
        match.update(victory: false)
        expect(match.result_text).to eq('Defeat')
      end
    end

    describe '#duration_formatted' do
      it 'formats duration correctly' do
        expect(match.duration_formatted).to eq('30:00')
      end
    end
  end

  describe 'scopes' do
    let(:organization) { create(:organization) }
    let!(:victory) { create(:match, victory: true, organization: organization) }
    let!(:defeat) { create(:match, victory: false, organization: organization) }

    describe '.victories' do
      it 'returns only victories' do
        expect(Match.victories).to include(victory)
        expect(Match.victories).not_to include(defeat)
      end
    end

    describe '.defeats' do
      it 'returns only defeats' do
        expect(Match.defeats).to include(defeat)
        expect(Match.defeats).not_to include(victory)
      end
    end
  end
end
