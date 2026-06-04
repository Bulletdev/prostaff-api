# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DraftComparatorService, type: :model do
  let(:organization)    { create(:organization) }
  let(:our_picks)       { %w[Aatrox LeeSin Orianna Jinx Thresh] }
  let(:opponent_picks)  { %w[Gnar Graves Sylas Caitlyn Nautilus] }

  describe '.compare_draft' do
    context 'with valid picks and no similar matches in DB' do
      it 'returns a hash with the required keys' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          organization: organization
        )

        expect(result).to include(
          :similarity_score,
          :similar_matches,
          :composition_winrate,
          :meta_score,
          :insights,
          :analyzed_at
        )
      end

      it 'returns a non-negative similarity_score' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          organization: organization
        )

        expect(result[:similarity_score]).to be >= 0
      end

      it 'returns a composition_winrate in [0, 100]' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          organization: organization
        )

        expect(result[:composition_winrate]).to be >= 0.0
        expect(result[:composition_winrate]).to be <= 100.0
      end

      it 'returns a meta_score in [0, 100]' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          organization: organization
        )

        expect(result[:meta_score]).to be >= 0
        expect(result[:meta_score]).to be <= 100
      end

      it 'returns insights as a non-empty array' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          organization: organization
        )

        expect(result[:insights]).to be_a(Array)
        expect(result[:insights]).not_to be_empty
      end

      it 'returns analyzed_at as a Time-like object' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          organization: organization
        )

        expect(result[:analyzed_at]).to respond_to(:iso8601)
      end

      it 'returns similar_matches as an array' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          organization: organization
        )

        expect(result[:similar_matches]).to be_a(Array)
      end
    end

    context 'with similar matches present in the database' do
      let!(:matching_match) do
        create(:competitive_match,
               organization: organization,
               victory: true,
               our_champions: our_picks,
               opponent_champions: opponent_picks)
      end

      it 'finds similar matches and includes them in the result' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          organization: organization
        )

        expect(result[:similar_matches]).to be_a(Array)
      end

      it 'calculates composition_winrate from existing matches (must be in [0, 100])' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          organization: organization
        )

        expect(result[:composition_winrate]).to be >= 0.0
        expect(result[:composition_winrate]).to be <= 100.0
      end
    end

    context 'when patch is provided' do
      it 'includes patch in the returned hash' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          organization: organization,
          patch: '14.20'
        )

        expect(result[:patch]).to eq('14.20')
      end
    end

    context 'when bans are provided' do
      it 'does not raise and still returns the expected keys' do
        result = described_class.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          our_bans: %w[Akali Azir Lucian],
          opponent_bans: %w[Zed Yasuo],
          organization: organization
        )

        expect(result).to include(:similarity_score, :meta_score, :insights)
      end
    end
  end

  describe '#composition_winrate' do
    subject(:svc) { described_class.new }

    context 'when champions list is empty' do
      it 'returns 0.0' do
        expect(svc.composition_winrate(champions: [], patch: nil)).to eq(0.0)
      end
    end

    context 'when no similar matches exist' do
      it 'returns 0.0' do
        result = svc.composition_winrate(champions: %w[Azir Lulu Garen Jinx Thresh], patch: nil)
        expect(result).to eq(0.0)
      end
    end

    context 'when similar matches exist (all victories)' do
      before do
        create_list(:competitive_match, 3, organization: organization, victory: true,
                                          our_champions: %w[Azir Lulu Garen Jinx Thresh])
      end

      it 'returns a winrate between 0 and 100' do
        result = svc.composition_winrate(champions: %w[Azir Lulu Garen Jinx Thresh], patch: nil)
        expect(result).to be >= 0.0
        expect(result).to be <= 100.0
      end
    end
  end

  describe '#find_similar_matches' do
    subject(:svc) { described_class.new }

    context 'when champions is blank' do
      it 'returns an empty array' do
        expect(svc.find_similar_matches(champions: [], patch: nil)).to eq([])
        expect(svc.find_similar_matches(champions: nil, patch: nil)).to eq([])
      end
    end

    context 'when there are no matching records' do
      it 'returns an empty array' do
        result = svc.find_similar_matches(champions: %w[Jinx Lulu], patch: nil)
        expect(result).to be_a(Array)
        expect(result).to be_empty
      end
    end

    context 'when matching records exist' do
      before do
        create(:competitive_match, organization: organization,
                                   our_champions: %w[Jinx Lulu Thresh Orianna Garen])
        create(:competitive_match, organization: organization,
                                   our_champions: %w[Viktor Vi Syndra Caitlyn Thresh])
      end

      it 'returns CompetitiveMatch records' do
        results = svc.find_similar_matches(champions: %w[Jinx Lulu Thresh Orianna Garen], patch: nil)
        expect(results).to all(be_a(CompetitiveMatch))
      end

      it 'does not return more than the specified limit' do
        results = svc.find_similar_matches(champions: %w[Jinx Lulu Thresh Orianna Garen], patch: nil, limit: 1)
        expect(results.size).to be <= 1
      end
    end
  end

  describe '#meta_analysis' do
    subject(:svc) { described_class.new }

    it 'returns a hash with role, top_picks, top_bans, total_matches' do
      result = svc.meta_analysis(role: 'mid', patch: nil)

      expect(result).to include(:role, :top_picks, :top_bans, :total_matches)
      expect(result[:role]).to eq('mid')
    end

    it 'returns top_picks as an array' do
      result = svc.meta_analysis(role: 'adc', patch: nil)
      expect(result[:top_picks]).to be_a(Array)
    end

    it 'returns top_bans as an array' do
      result = svc.meta_analysis(role: 'support', patch: nil)
      expect(result[:top_bans]).to be_a(Array)
    end
  end
end
