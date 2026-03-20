# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompetitiveMatch, type: :model do
  let(:org) { create(:organization) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:opponent_team).optional }
    it { should belong_to(:match).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:tournament_name) }

    it 'is invalid with an unknown side' do
      m = build(:competitive_match, organization: org, side: 'center')
      expect(m).not_to be_valid
    end

    it 'is valid with blue side' do
      m = build(:competitive_match, organization: org, side: 'blue')
      expect(m).to be_valid
    end

    it 'is valid with red side' do
      m = build(:competitive_match, organization: org, side: 'red')
      expect(m).to be_valid
    end

    it 'is invalid with game_number > 5' do
      m = build(:competitive_match, organization: org, game_number: 6)
      expect(m).not_to be_valid
    end

    it 'is invalid with game_number < 1' do
      m = build(:competitive_match, organization: org, game_number: 0)
      expect(m).not_to be_valid
    end
  end

  describe '#has_complete_draft?' do
    it 'returns true when both teams have 5 picks' do
      m = create(:competitive_match, organization: org)
      expect(m.has_complete_draft?).to be true
    end

    it 'returns false when picks are missing' do
      m = build(:competitive_match, organization: org, our_picks: [], opponent_picks: [])
      expect(m.has_complete_draft?).to be false
    end
  end

  describe '#our_picked_champions' do
    it 'returns an array of champion names' do
      m = create(:competitive_match, organization: org)
      names = m.our_picked_champions
      expect(names).to be_an(Array)
      names.each { |name| expect(name).to be_a(String) }
    end
  end

  describe '#draft_summary' do
    it 'returns keys for bans and picks for both teams' do
      m = create(:competitive_match, organization: org)
      summary = m.draft_summary
      expect(summary).to have_key(:our_picks)
      expect(summary).to have_key(:opponent_picks)
      expect(summary).to have_key(:our_bans)
      expect(summary).to have_key(:opponent_bans)
      expect(summary).to have_key(:side)
    end
  end

  describe '#result_text' do
    it 'returns Victory for a winning match' do
      m = build(:competitive_match, organization: org, victory: true)
      expect(m.result_text).to eq('Victory')
    end

    it 'returns Defeat for a losing match' do
      m = build(:competitive_match, organization: org, victory: false)
      expect(m.result_text).to eq('Defeat')
    end
  end

  describe 'scopes' do
    let!(:win)  { create(:competitive_match, organization: org, victory: true,  side: 'blue') }
    let!(:loss) { create(:competitive_match, organization: org, victory: false, side: 'red') }
    # Use unscoped to bypass the OrganizationScoped default_scope (requires Current.organization_id)
    let(:matches) { CompetitiveMatch.unscoped.where(organization: org) }

    it '.victories returns only winning matches' do
      expect(matches.victories).to include(win)
      expect(matches.victories).not_to include(loss)
    end

    it '.defeats returns only losing matches' do
      expect(matches.defeats).to include(loss)
      expect(matches.defeats).not_to include(win)
    end

    it '.blue_side returns only blue side matches' do
      expect(matches.blue_side).to include(win)
      expect(matches.blue_side).not_to include(loss)
    end

    it '.by_tournament filters by tournament name' do
      cblol = create(:competitive_match, organization: org, tournament_name: 'CBLOL')
      expect(matches.by_tournament('CBLOL')).to include(cblol)
      expect(matches.by_tournament('CBLOL')).not_to include(win)
    end
  end
end
