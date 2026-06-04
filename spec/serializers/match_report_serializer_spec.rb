# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatchReportSerializer do
  let(:tournament) { create(:tournament) }
  let(:org) { create(:organization) }
  let(:tournament_match) { create(:tournament_match, tournament: tournament) }
  let(:tournament_team) { create(:tournament_team, tournament: tournament, organization: org) }
  let(:match_report) do
    create(:match_report,
           tournament_match: tournament_match,
           tournament_team: tournament_team,
           team_a_score: 2,
           team_b_score: 1)
  end

  subject(:result) { described_class.new(match_report).as_json }

  it 'exposes identifier' do
    expect(result[:id]).to eq(match_report.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :tournament_match_id, :tournament_team_id,
      :team_a_score, :team_b_score,
      :evidence_url, :status,
      :submitted_at, :confirmed_at, :deadline_at
    )
  end

  describe 'team_a_score field' do
    it 'is non-negative' do
      expect(result[:team_a_score]).to be >= 0
    end
  end

  describe 'team_b_score field' do
    it 'is non-negative' do
      expect(result[:team_b_score]).to be >= 0
    end
  end

  describe 'status field' do
    it 'is a string' do
      expect(result[:status]).to be_a(String)
    end

    it 'is a known status value' do
      expect(result[:status]).to be_in(%w[submitted confirmed disputed])
    end
  end

  describe 'tournament_match_id field' do
    it 'matches the associated tournament match' do
      expect(result[:tournament_match_id]).to eq(tournament_match.id)
    end
  end

  describe 'tournament_team_id field' do
    it 'matches the associated tournament team' do
      expect(result[:tournament_team_id]).to eq(tournament_team.id)
    end
  end

  describe 'when report is nil' do
    subject(:null_result) { described_class.new(nil).as_json }

    it 'returns nil' do
      expect(null_result).to be_nil
    end
  end
end
