# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatchConfirmationService do
  let(:tournament)  { create(:tournament, :in_progress) }
  let(:team_a)      { create(:tournament_team, :approved, tournament: tournament) }
  let(:team_b)      { create(:tournament_team, :approved, tournament: tournament) }
  let(:match)       { create(:tournament_match, :awaiting_report, tournament: tournament, team_a: team_a, team_b: team_b) }
  let(:user)        { create(:user) }
  let(:evidence)    { 'https://example.com/proof.png' }

  def call_service(team:, a_score: 2, b_score: 1, ev: evidence)
    described_class.new(
      match: match,
      team: team,
      user: user,
      team_a_score: a_score,
      team_b_score: b_score,
      evidence_url: ev
    ).call
  end

  describe '#call' do
    context 'when first captain reports' do
      subject(:result) { call_service(team: team_a) }

      it 'returns status :submitted' do
        expect(result[:status]).to eq(:submitted)
      end

      it 'creates a match report' do
        expect { result }.to change(MatchReport, :count).by(1)
      end

      it 'transitions match to awaiting_confirm' do
        result
        expect(match.reload.status).to eq('awaiting_confirm')
      end
    end

    context 'when both captains report matching scores' do
      before { call_service(team: team_a, a_score: 2, b_score: 1) }

      subject(:result) { call_service(team: team_b, a_score: 2, b_score: 1) }

      it 'returns status :confirmed' do
        expect(result[:status]).to eq(:confirmed)
      end

      it 'confirms both reports' do
        result
        expect(match.match_reports.pluck(:status).uniq).to eq(['confirmed'])
      end

      it 'advances the bracket' do
        expect { result }.to change { match.reload.status }.to('completed')
      end
    end

    context 'when captains report diverging scores' do
      before { call_service(team: team_a, a_score: 2, b_score: 1) }

      subject(:result) { call_service(team: team_b, a_score: 1, b_score: 2) }

      it 'returns status :disputed' do
        expect(result[:status]).to eq(:disputed)
      end

      it 'transitions match to disputed' do
        result
        expect(match.reload.status).to eq('disputed')
      end
    end

    context 'when evidence_url is blank' do
      subject(:result) { call_service(team: team_a, ev: '') }

      it 'returns status :error' do
        expect(result[:status]).to eq(:error)
      end

      it 'includes a meaningful message' do
        expect(result[:message]).to include('Evidence')
      end
    end

    context 'when team is not a match participant' do
      let(:outsider) { create(:tournament_team, :approved, tournament: tournament) }

      subject(:result) { call_service(team: outsider) }

      it 'returns status :error' do
        expect(result[:status]).to eq(:error)
      end
    end
  end
end
