# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BracketProgressionService do
  # Tournament with two approved teams
  let(:tournament) { create(:tournament, :in_progress, max_teams: 2) }
  let(:org_a)  { create(:organization) }
  let(:org_b)  { create(:organization) }
  let(:team_a) { create(:tournament_team, :approved, tournament: tournament, organization: org_a, team_name: 'Team Alpha', team_tag: 'ALPH') }
  let(:team_b) { create(:tournament_team, :approved, tournament: tournament, organization: org_b, team_name: 'Team Beta', team_tag: 'BETA') }

  # ── Basic match with no next-match links (grand final scenario) ────────────

  let(:grand_final) do
    create(:tournament_match, tournament: tournament,
                               bracket_side: 'grand_final',
                               round_label: 'Grand Final',
                               round_order: 10,
                               match_number: 1,
                               team_a: team_a,
                               team_b: team_b,
                               status: 'awaiting_report',
                               next_match_winner_id: nil,
                               next_match_loser_id: nil)
  end

  # ── UB match that feeds into next match ──────────────────────────────────

  let(:next_winner_match) do
    create(:tournament_match, tournament: tournament,
                               bracket_side: 'upper',
                               round_label: 'UB Round 2',
                               round_order: 2,
                               match_number: 1,
                               status: 'scheduled')
  end

  let(:next_loser_match) do
    create(:tournament_match, tournament: tournament,
                               bracket_side: 'lower',
                               round_label: 'LB Round 1',
                               round_order: 3,
                               match_number: 1,
                               status: 'scheduled')
  end

  let(:ub_match) do
    create(:tournament_match, tournament: tournament,
                               bracket_side: 'upper',
                               round_label: 'UB Round 1',
                               round_order: 1,
                               match_number: 1,
                               team_a: team_a,
                               team_b: team_b,
                               status: 'awaiting_report',
                               next_match_winner_id: next_winner_match.id,
                               next_match_loser_id: next_loser_match.id)
  end

  describe '#call' do
    # ── Grand Final completion sets tournament to finished ─────────────────

    context 'when the completed match is the grand final' do
      subject(:service) { described_class.new(grand_final, winner: team_a, loser: team_b) }

      it 'sets the tournament status to finished' do
        service.call
        expect(tournament.reload.status).to eq('finished')
      end

      it 'sets finished_at on the tournament' do
        service.call
        expect(tournament.reload.finished_at).to be_present
      end

      it 'finalizes the match with the correct winner and loser' do
        service.call
        grand_final.reload
        expect(grand_final.winner_id).to eq(team_a.id)
        expect(grand_final.loser_id).to eq(team_b.id)
        expect(grand_final.status).to eq('completed')
        expect(grand_final.completed_at).to be_present
      end
    end

    # ── Non-final match: winner advances to next_match_winner ─────────────

    context 'when next_match_winner_id is set' do
      subject(:service) { described_class.new(ub_match, winner: team_a, loser: team_b) }

      it 'places the winner into the next winner match as team_a (first open slot)' do
        service.call
        expect(next_winner_match.reload.team_a_id).to eq(team_a.id)
      end

      it 'does not set tournament to finished' do
        service.call
        expect(tournament.reload.status).to eq('in_progress')
      end
    end

    # ── Non-final match: loser drops to next_match_loser (double-elim) ────

    context 'when next_match_loser_id is set' do
      subject(:service) { described_class.new(ub_match, winner: team_a, loser: team_b) }

      it 'places the loser into the lower bracket match as team_a (first open slot)' do
        service.call
        expect(next_loser_match.reload.team_a_id).to eq(team_b.id)
      end
    end

    # ── Slot assignment: fills team_b when team_a already occupied ─────────

    context 'when the next winner match already has team_a populated' do
      before do
        # Pre-fill team_a slot so winner must go to team_b
        next_winner_match.update!(team_a: team_b)
      end

      subject(:service) { described_class.new(ub_match, winner: team_a, loser: team_b) }

      it 'places winner into team_b slot of next match' do
        service.call
        expect(next_winner_match.reload.team_b_id).to eq(team_a.id)
      end
    end

    # ── nil next_match_winner_id: no new match slot created ───────────────

    context 'when next_match_winner_id is nil' do
      let(:terminal_match) do
        create(:tournament_match, tournament: tournament,
                                   bracket_side: 'upper',
                                   round_label: 'UB Round 1',
                                   round_order: 1,
                                   match_number: 2,
                                   team_a: team_a,
                                   team_b: team_b,
                                   status: 'awaiting_report',
                                   next_match_winner_id: nil,
                                   next_match_loser_id: nil)
      end

      it 'does not raise and does not update any other match' do
        expect { described_class.new(terminal_match, winner: team_a, loser: team_b).call }
          .not_to raise_error
      end
    end

    # ── Custom status parameter ────────────────────────────────────────────

    context 'when a custom status is provided (walkover)' do
      subject(:service) do
        described_class.new(grand_final, winner: team_a, loser: team_b, status: 'walkover')
      end

      it 'sets the match to the custom status' do
        service.call
        expect(grand_final.reload.status).to eq('walkover')
      end
    end

    # ── Transaction rollback ───────────────────────────────────────────────

    context 'when an error occurs mid-transaction' do
      it 'rolls back all changes' do
        allow(tournament).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

        expect { described_class.new(grand_final, winner: team_a, loser: team_b).call }
          .to raise_error(ActiveRecord::RecordInvalid)

        expect(grand_final.reload.winner_id).to be_nil
      end
    end
  end
end
