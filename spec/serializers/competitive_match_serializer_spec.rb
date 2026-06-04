# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompetitiveMatchSerializer do
  let(:organization) { create(:organization) }
  let(:competitive_match) { create(:competitive_match, organization: organization) }

  subject(:result) { described_class.new(competitive_match).as_json }

  it 'exposes identifier' do
    expect(result[:id]).to eq(competitive_match.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :tournament_name, :tournament_stage, :tournament_region,
      :match_date, :match_format, :game_number,
      :our_team_name, :opponent_team_name,
      :victory, :result_text, :series_score, :side, :patch_version,
      :created_at, :updated_at
    )
  end

  describe 'status field' do
    it 'is NOT present (CompetitiveMatch has no status column)' do
      expect(result).not_to have_key(:status)
    end
  end

  describe 'meta_relevant field' do
    it 'is a boolean' do
      expect(result[:meta_relevant]).to be_in([true, false])
    end
  end

  describe 'opponent_team field' do
    context 'when no opponent team is linked' do
      it 'is nil' do
        expect(result[:opponent_team]).to be_nil
      end
    end

    context 'when an opponent team is linked' do
      let(:opponent_team) { create(:opponent_team) }
      let(:competitive_match) do
        create(:competitive_match, organization: organization, opponent_team: opponent_team)
      end

      it 'includes the opponent team id' do
        expect(result[:opponent_team][:id]).to eq(opponent_team.id)
      end

      it 'includes name and tag' do
        expect(result[:opponent_team]).to include(:name, :tag)
      end
    end
  end

  describe 'detailed mode' do
    subject(:detailed_result) { described_class.new(competitive_match, detailed: true).as_json }

    it 'includes draft data' do
      expect(detailed_result).to include(
        :has_complete_draft,
        :our_picked_champions,
        :opponent_picked_champions
      )
    end

    it 'includes vod_url' do
      expect(detailed_result).to have_key(:vod_url)
    end
  end

  describe 'cross-org isolation' do
    let(:other_org) { create(:organization) }
    let(:other_match) { create(:competitive_match, organization: other_org) }

    it 'serializes only its own organization_id' do
      expect(result[:organization_id]).to eq(organization.id)
      expect(result[:organization_id]).not_to eq(other_org.id)
    end
  end
end
