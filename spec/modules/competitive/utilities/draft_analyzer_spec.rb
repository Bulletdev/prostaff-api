# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Competitive::Utilities::DraftAnalyzer, type: :model do
  let(:organization) { create(:organization) }

  describe '.calculate_meta_score' do
    context 'when picks is blank' do
      it 'returns 0 for empty array' do
        expect(described_class.calculate_meta_score([], nil)).to eq(0)
      end

      it 'returns 0 for nil' do
        expect(described_class.calculate_meta_score(nil, nil)).to eq(0)
      end
    end

    context 'when no competitive matches exist' do
      it 'returns 0' do
        result = described_class.calculate_meta_score(%w[Jinx Lulu Thresh Orianna Garen], nil)
        expect(result).to eq(0)
      end
    end

    context 'when competitive matches exist' do
      before do
        create_list(:competitive_match, 5, organization: organization,
                                          our_champions: %w[Jinx Lulu Thresh Orianna Garen])
      end

      it 'returns a Float in [0, 100]' do
        result = described_class.calculate_meta_score(%w[Jinx Lulu Thresh Orianna Garen], nil)
        expect(result).to be_a(Numeric)
        expect(result).to be >= 0
        expect(result).to be <= 100
      end

      it 'is capped at 100' do
        result = described_class.calculate_meta_score(%w[Jinx Lulu Thresh Orianna Garen], nil)
        expect(result).to be <= 100
      end
    end
  end

  describe '.calculate_similarity_score' do
    context 'when similar_matches is empty' do
      it 'returns 0' do
        expect(described_class.calculate_similarity_score(%w[Jinx Lulu], [])).to eq(0)
      end
    end

    context 'with matching data' do
      let!(:match) do
        create(:competitive_match, organization: organization,
                                   our_champions: %w[Jinx Lulu Thresh Orianna Garen])
      end

      it 'returns a value in [0, 100]' do
        result = described_class.calculate_similarity_score(
          %w[Jinx Lulu Thresh Orianna Garen],
          [match]
        )
        expect(result).to be >= 0
        expect(result).to be <= 100
      end

      it 'returns 100 for a perfect match' do
        result = described_class.calculate_similarity_score(
          %w[Jinx Lulu Thresh Orianna Garen],
          [match]
        )
        # Perfect overlap = 5/5 * 100 = 100.0
        expect(result).to eq(100.0)
      end

      it 'returns a value between 0 and 100 for partial match' do
        result = described_class.calculate_similarity_score(
          %w[Jinx Lulu Viktor Azir Jayce],
          [match]
        )
        expect(result).to be >= 0
        expect(result).to be < 100
      end
    end
  end

  describe '.generate_insights' do
    let(:insights_params) do
      {
        _our_picks: %w[Jinx Lulu Thresh Orianna Garen],
        opponent_picks: %w[Caitlyn Zyra Renekton Azir Graves],
        our_bans: %w[Akali Zed],
        similar_matches: [],
        meta_score: 55.0,
        patch: nil
      }
    end

    it 'returns an Array' do
      result = described_class.generate_insights(**insights_params)
      expect(result).to be_a(Array)
    end

    it 'returns at least one insight' do
      result = described_class.generate_insights(**insights_params)
      expect(result).not_to be_empty
    end

    it 'returns strings as insight items' do
      result = described_class.generate_insights(**insights_params)
      expect(result).to all(be_a(String))
    end

    context 'with a high meta_score (>= 70)' do
      it 'includes a meta relevance message' do
        result = described_class.generate_insights(**insights_params.merge(meta_score: 75.0))
        expect(result.join(' ')).to include('75')
      end
    end

    context 'with similar matches present' do
      let!(:victory_match) do
        create(:competitive_match, organization: organization,
                                   victory: true,
                                   our_champions: %w[Jinx Lulu Thresh Orianna Garen])
      end

      it 'includes additional insights from similar matches' do
        result = described_class.generate_insights(
          **insights_params.merge(similar_matches: [victory_match])
        )
        expect(result.size).to be >= 2
      end
    end

    context 'with a patch specified' do
      it 'includes the patch version in insights' do
        result = described_class.generate_insights(**insights_params.merge(patch: '14.20'))
        expect(result.join(' ')).to include('14.20')
      end
    end

    context 'without a patch' do
      it 'returns a cross-patch warning' do
        result = described_class.generate_insights(**insights_params.merge(patch: nil))
        expect(result.join(' ')).to match(/cross.patch|patch atual/i)
      end
    end
  end

  describe '.format_match' do
    let!(:match) do
      create(:competitive_match,
             organization: organization,
             tournament_name: 'CBLOL 2025',
             tournament_stage: 'Finals',
             victory: true,
             our_champions: %w[Jinx Lulu Thresh Orianna Garen],
             opponent_champions: %w[Caitlyn Zyra Renekton Azir Graves])
    end

    it 'returns a hash with all required keys' do
      result = described_class.format_match(match)

      expect(result).to include(:id, :tournament, :date, :result, :our_picks, :opponent_picks, :patch)
    end

    it 'sets result to Victory for a victory match' do
      result = described_class.format_match(match)
      expect(result[:result]).to eq('Victory')
    end

    it 'sets result to Defeat for a defeat match' do
      defeat_match = create(:competitive_match, organization: organization, victory: false)
      result = described_class.format_match(defeat_match)
      expect(result[:result]).to eq('Defeat')
    end

    it 'returns our_picks as an array of champion names' do
      result = described_class.format_match(match)
      expect(result[:our_picks]).to be_a(Array)
      expect(result[:our_picks]).to all(be_a(String))
    end

    it 'returns opponent_picks as an array of champion names' do
      result = described_class.format_match(match)
      expect(result[:opponent_picks]).to be_a(Array)
    end

    it 'returns the tournament display name' do
      result = described_class.format_match(match)
      expect(result[:tournament]).to include('CBLOL 2025')
    end
  end

  describe '.calculate_pick_frequency' do
    context 'when picks is empty' do
      it 'returns an empty array' do
        expect(described_class.calculate_pick_frequency([])).to eq([])
      end
    end

    context 'with a list of picks' do
      let(:picks) { %w[Jinx Jinx Lulu Thresh Jinx Lulu] }

      it 'returns an array of hashes with champion, picks, pick_rate' do
        result = described_class.calculate_pick_frequency(picks)
        expect(result).to be_a(Array)
        expect(result.first).to include(:champion, :picks, :pick_rate)
      end

      it 'sorts by frequency descending' do
        result = described_class.calculate_pick_frequency(picks)
        frequencies = result.map { |r| r[:picks] }
        expect(frequencies).to eq(frequencies.sort.reverse)
      end

      it 'calculates pick_rate as a percentage in [0, 100]' do
        result = described_class.calculate_pick_frequency(picks)
        result.each do |entry|
          expect(entry[:pick_rate]).to be >= 0.0
          expect(entry[:pick_rate]).to be <= 100.0
        end
      end

      it 'returns at most 10 entries' do
        many_picks = (1..20).map { |i| "Champion#{i}" }.concat(%w[Jinx Jinx Lulu])
        result = described_class.calculate_pick_frequency(many_picks)
        expect(result.size).to be <= 10
      end
    end
  end

  describe '.calculate_ban_frequency' do
    context 'when bans is empty' do
      it 'returns an empty array' do
        expect(described_class.calculate_ban_frequency([])).to eq([])
      end
    end

    context 'with a list of bans' do
      let(:bans) { %w[Akali Akali Zed Yasuo Akali] }

      it 'returns hashes with champion, bans, ban_rate' do
        result = described_class.calculate_ban_frequency(bans)
        expect(result.first).to include(:champion, :bans, :ban_rate)
      end

      it 'calculates ban_rate as a percentage in [0, 100]' do
        result = described_class.calculate_ban_frequency(bans)
        result.each do |entry|
          expect(entry[:ban_rate]).to be >= 0.0
          expect(entry[:ban_rate]).to be <= 100.0
        end
      end
    end
  end

  describe '.extract_bans' do
    let!(:match) do
      m = create(:competitive_match, organization: organization)
      m.update_columns(
        our_bans: [{ 'champion' => 'Akali', 'order' => 1 }, { 'champion' => 'Zed', 'order' => 2 }],
        opponent_bans: [{ 'champion' => 'Yasuo', 'order' => 1 }]
      )
      m
    end

    it 'returns an array of all banned champion names' do
      result = described_class.extract_bans(match)
      expect(result).to be_a(Array)
      expect(result).to include('Akali', 'Zed', 'Yasuo')
    end

    it 'returns the combined count of both teams bans' do
      result = described_class.extract_bans(match)
      expect(result.size).to eq(3)
    end
  end

  describe '.extract_role_picks' do
    let!(:match) do
      m = create(:competitive_match, organization: organization)
      m.update_columns(
        our_picks: [
          { 'champion' => 'Garen', 'role' => 'top' },
          { 'champion' => 'Lee Sin', 'role' => 'jungle' },
          { 'champion' => 'Orianna', 'role' => 'mid' },
          { 'champion' => 'Jinx', 'role' => 'adc' },
          { 'champion' => 'Thresh', 'role' => 'support' }
        ],
        opponent_picks: [
          { 'champion' => 'Renekton', 'role' => 'top' },
          { 'champion' => 'Graves', 'role' => 'jungle' },
          { 'champion' => 'Azir', 'role' => 'mid' },
          { 'champion' => 'Caitlyn', 'role' => 'adc' },
          { 'champion' => 'Nautilus', 'role' => 'support' }
        ]
      )
      m
    end

    it 'returns champions for the specified role from both teams' do
      result = described_class.extract_role_picks(match, 'mid')
      expect(result).to include('Orianna', 'Azir')
    end

    it 'returns an empty array for a role not present in the match' do
      result = described_class.extract_role_picks(match, 'nonexistent_role')
      expect(result).to be_a(Array)
      expect(result).to be_empty
    end

    it 'is case-insensitive for role matching' do
      result = described_class.extract_role_picks(match, 'TOP')
      expect(result).to include('Garen')
    end
  end

  describe '.build_meta_analysis_response' do
    let(:picks) { %w[Jinx Caitlyn Jinx Ezreal Caitlyn] }
    let(:bans)  { %w[Akali Zed Akali] }

    it 'returns a hash with role, patch, top_picks, top_bans, total_matches' do
      result = described_class.build_meta_analysis_response('adc', '14.20', picks, bans, 10)

      expect(result).to include(:role, :patch, :top_picks, :top_bans, :total_matches)
    end

    it 'sets role and patch correctly' do
      result = described_class.build_meta_analysis_response('adc', '14.20', picks, bans, 10)

      expect(result[:role]).to eq('adc')
      expect(result[:patch]).to eq('14.20')
      expect(result[:total_matches]).to eq(10)
    end

    it 'returns top_picks sorted by frequency' do
      result = described_class.build_meta_analysis_response('adc', nil, picks, bans, 5)

      expect(result[:top_picks]).to be_a(Array)
      expect(result[:top_picks].first[:champion]).to be_present
    end
  end
end
