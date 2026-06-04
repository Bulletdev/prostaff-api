# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatchSerializer do
  let(:organization) { create(:organization) }
  let(:match) { create(:match, organization: organization) }

  subject(:result) { described_class.render_as_hash(match) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(match.id)
  end

  it 'exposes core match fields' do
    expect(result).to include(
      :match_type, :game_start, :game_end, :game_duration,
      :opponent_name, :victory, :our_side,
      :our_score, :opponent_score,
      :created_at, :updated_at
    )
  end

  describe 'result field' do
    it 'is a string' do
      expect(result[:result]).to be_a(String)
    end
  end

  describe 'duration_formatted field' do
    it 'is a string' do
      expect(result[:duration_formatted]).to be_a(String)
    end
  end

  describe 'score_display field' do
    it 'is a string' do
      expect(result[:score_display]).to be_a(String)
    end
  end

  describe 'kda_summary field' do
    it 'is present' do
      expect(result).to have_key(:kda_summary)
    end
  end

  describe 'has_replay field' do
    it 'is a boolean' do
      expect(result[:has_replay]).to be_in([true, false])
    end
  end

  describe 'has_vod field' do
    it 'is a boolean' do
      expect(result[:has_vod]).to be_in([true, false])
    end
  end

  describe 'organization association' do
    it 'includes the associated organization id' do
      expect(result[:organization][:id]).to eq(organization.id)
    end
  end

  describe 'victory field' do
    context 'when match is a victory' do
      let(:match) { create(:match, organization: organization, victory: true) }

      it 'is true' do
        expect(result[:victory]).to be(true)
      end
    end

    context 'when match is a loss' do
      let(:match) { create(:match, organization: organization, victory: false) }

      it 'is false' do
        expect(result[:victory]).to be(false)
      end
    end
  end
end
