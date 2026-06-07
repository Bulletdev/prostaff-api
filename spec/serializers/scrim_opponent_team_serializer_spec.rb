# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScrimOpponentTeamSerializer do
  let(:opponent_team) do
    create(:opponent_team,
           name: 'Team Dragon',
           tag: 'TDG',
           region: 'BR',
           tier: 'tier_2',
           total_scrims: 10,
           scrims_won: 6,
           scrims_lost: 4)
  end

  subject(:result) { described_class.new(opponent_team).as_json }

  it 'exposes identifier' do
    expect(result[:id]).to eq(opponent_team.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :name, :tag, :full_name, :region, :tier, :tier_display,
      :league, :logo_url, :total_scrims, :scrim_record,
      :scrim_win_rate, :created_at, :updated_at
    )
  end

  describe 'scrim_win_rate field' do
    it 'is within 0 to 100' do
      expect(result[:scrim_win_rate]).to be >= 0.0
      expect(result[:scrim_win_rate]).to be <= 100.0
    end

    it 'calculates 60.0 from 6 wins out of 10' do
      expect(result[:scrim_win_rate]).to eq(60.0)
    end

    context 'when no scrims have been played' do
      let(:opponent_team) { create(:opponent_team, total_scrims: 0, scrims_won: 0, scrims_lost: 0) }

      it 'returns 0 without raising' do
        expect(result[:scrim_win_rate]).to eq(0)
      end
    end
  end

  describe 'scrim_record field' do
    it 'is a string in W-L format' do
      expect(result[:scrim_record]).to eq('6W - 4L')
    end
  end

  describe 'detailed mode' do
    subject(:detailed) { described_class.new(opponent_team, detailed: true).as_json }

    it 'includes detailed fields' do
      expect(detailed).to include(
        :known_players, :playstyle_notes,
        :strengths, :weaknesses, :preferred_champions,
        :contact_email, :discord_server, :contact_available
      )
    end

    describe 'contact_available field' do
      it 'is a boolean' do
        expect(detailed[:contact_available]).to be_in([true, false])
      end
    end
  end
end
