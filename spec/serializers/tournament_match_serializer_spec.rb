# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TournamentMatchSerializer do
  let(:tournament) { create(:tournament) }
  let(:tournament_match) { create(:tournament_match, tournament: tournament) }

  subject(:result) { described_class.new(tournament_match).as_json }

  it 'exposes bracket fields' do
    expect(result).to include(
      :id, :tournament_id, :bracket_side, :round_label,
      :round_order, :match_number, :bo_format, :status
    )
  end

  it 'exposes team fields' do
    expect(result).to include(
      :team_a_id, :team_a_name, :team_a_tag, :team_a_logo, :team_a_score,
      :team_b_id, :team_b_name, :team_b_tag, :team_b_logo, :team_b_score,
      :winner_id, :loser_id
    )
  end

  it 'exposes schedule fields' do
    expect(result).to include(
      :scheduled_at, :checkin_opens_at, :checkin_deadline_at,
      :wo_deadline_at, :started_at, :completed_at
    )
  end

  describe 'status field' do
    it 'is a valid lifecycle value' do
      expect(result[:status]).to be_in(
        %w[scheduled checkin_open in_progress awaiting_report disputed completed]
      )
    end
  end

  describe 'team_a_score and team_b_score fields' do
    it 'default to 0 before the match is played (NOT NULL default in schema)' do
      expect(result[:team_a_score]).to eq(0)
      expect(result[:team_b_score]).to eq(0)
    end

    context 'when completed with scores' do
      let(:tournament_match) do
        create(:tournament_match, :completed, tournament: tournament,
                                              team_a_score: 2, team_b_score: 0)
      end

      it 'has non-negative scores' do
        expect(result[:team_a_score]).to be >= 0
        expect(result[:team_b_score]).to be >= 0
      end

      it 'exposes correct score values' do
        expect(result[:team_a_score]).to eq(2)
        expect(result[:team_b_score]).to eq(0)
      end
    end
  end

  describe 'tournament_id field' do
    it 'matches the tournament' do
      expect(result[:tournament_id]).to eq(tournament.id)
    end
  end

  describe 'when both teams are assigned' do
    let(:org_a) { create(:organization) }
    let(:org_b) { create(:organization) }
    let(:team_a) do
      create(:tournament_team, tournament: tournament, organization: org_a, team_name: 'Alpha')
    end
    let(:team_b) do
      create(:tournament_team, tournament: tournament, organization: org_b, team_name: 'Beta')
    end
    let(:tournament_match) do
      create(:tournament_match, tournament: tournament, team_a: team_a, team_b: team_b)
    end

    it 'includes team names' do
      expect(result[:team_a_name]).to eq('Alpha')
      expect(result[:team_b_name]).to eq('Beta')
    end
  end
end
