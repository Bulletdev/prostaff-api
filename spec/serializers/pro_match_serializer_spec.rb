# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProMatchSerializer do
  let(:organization) { create(:organization) }
  let(:pro_match) do
    create(:competitive_match,
           organization: organization,
           victory: true,
           side: 'blue',
           tournament_name: 'CBLOL 2024',
           tournament_stage: 'Grand Finals',
           tournament_region: 'BR',
           our_team_name: 'Team Prostaff',
           opponent_team_name: 'Team Rival',
           match_format: 'BO5',
           game_number: 1)
  end

  subject(:result) { described_class.render_as_hash(pro_match) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(pro_match.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :tournament_name, :tournament_stage, :tournament_region,
      :match_date, :match_format, :game_number,
      :our_team_name, :opponent_team_name,
      :victory, :series_score, :side, :patch_version,
      :vod_url, :external_stats_url,
      :created_at, :updated_at
    )
  end

  describe 'status field' do
    it 'is NOT present (CompetitiveMatch has no status column)' do
      expect(result).not_to have_key(:status)
    end
  end

  describe 'victory field' do
    it 'is a boolean' do
      expect(result[:victory]).to be_in([true, false])
    end

    context 'when victory is true' do
      it 'is true' do
        expect(result[:victory]).to be(true)
      end
    end
  end

  describe 'side field' do
    it 'is blue or red' do
      expect(result[:side]).to be_in(%w[blue red])
    end
  end

  describe 'result field' do
    it 'is a string' do
      expect(result[:result]).to be_a(String)
    end
  end

  describe 'tournament_display field' do
    it 'is a string' do
      expect(result[:tournament_display]).to be_a(String)
    end
  end

  describe 'game_label field' do
    it 'is present' do
      expect(result).to have_key(:game_label)
    end
  end

  describe 'has_complete_draft field' do
    it 'is a boolean' do
      expect(result[:has_complete_draft]).to be_in([true, false])
    end
  end

  describe 'meta_relevant field' do
    it 'is a boolean' do
      expect(result[:meta_relevant]).to be_in([true, false])
    end
  end

  describe 'our_picks field' do
    it 'is an array' do
      expect(result[:our_picks]).to be_an(Array)
    end
  end

  describe 'opponent_picks field' do
    it 'is an array' do
      expect(result[:opponent_picks]).to be_an(Array)
    end
  end

  describe 'our_bans field' do
    it 'is an array' do
      expect(result[:our_bans]).to be_an(Array)
    end
  end

  describe 'opponent_bans field' do
    it 'is an array' do
      expect(result[:opponent_bans]).to be_an(Array)
    end
  end

  describe 'our_team_logo field' do
    it 'is present in the result' do
      expect(result).to have_key(:our_team_logo)
    end
  end

  describe 'opponent_team_logo field' do
    it 'is present in the result' do
      expect(result).to have_key(:opponent_team_logo)
    end
  end
end
