# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TournamentTeamSerializer do
  let(:organization) { create(:organization) }
  let(:tournament) { create(:tournament) }
  let(:tournament_team) do
    create(:tournament_team,
           tournament: tournament,
           organization: organization)
  end

  subject(:result) { described_class.new(tournament_team).as_json }

  it 'exposes identifier' do
    expect(result[:id]).to eq(tournament_team.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :tournament_id, :organization_id,
      :team_name, :team_tag, :logo_url,
      :status, :seed, :bracket_side,
      :enrolled_at, :approved_at, :rejected_at
    )
  end

  describe 'status field' do
    it 'is a valid lifecycle value' do
      expect(result[:status]).to be_in(%w[pending approved rejected])
    end

    context 'when approved' do
      let(:tournament_team) do
        create(:tournament_team, :approved, tournament: tournament, organization: organization)
      end

      it 'is approved' do
        expect(result[:status]).to eq('approved')
      end

      it 'has approved_at timestamp' do
        expect(result[:approved_at]).to be_present
      end
    end

    context 'when rejected' do
      let(:tournament_team) do
        create(:tournament_team, :rejected, tournament: tournament, organization: organization)
      end

      it 'is rejected' do
        expect(result[:status]).to eq('rejected')
      end
    end
  end

  describe 'organization_id field' do
    it 'matches the associated organization' do
      expect(result[:organization_id]).to eq(organization.id)
    end
  end

  describe 'with_roster option' do
    context 'without with_roster' do
      it 'does not include roster key' do
        expect(result).not_to have_key(:roster)
      end
    end

    context 'with with_roster: true' do
      subject(:roster_result) { described_class.new(tournament_team, with_roster: true).as_json }

      it 'includes roster as an array' do
        expect(roster_result[:roster]).to be_an(Array)
      end

      context 'when roster snapshots exist' do
        let(:player) { create(:player, organization: organization) }

        before do
          create(:tournament_roster_snapshot,
                 tournament_team: tournament_team,
                 player: player,
                 role: 'mid')
        end

        it 'includes player_id and role in each snapshot' do
          expect(roster_result[:roster].first).to include(:player_id, :summoner_name, :role, :position)
        end

        it 'has role as a valid LoL role' do
          expect(roster_result[:roster].first[:role]).to be_in(%w[top jungle mid adc support])
        end
      end
    end
  end
end
