# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tournament, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }
    it { is_expected.to validate_inclusion_of(:game).in_array(described_class::GAMES) }
    it { is_expected.to validate_numericality_of(:max_teams).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:entry_fee_cents).is_greater_than_or_equal_to(0) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:tournament_teams).dependent(:destroy) }
    it { is_expected.to have_many(:tournament_matches).dependent(:destroy) }
  end

  describe '#registration_open?' do
    it 'returns true when status is registration_open' do
      tournament = build(:tournament, status: 'registration_open')
      expect(tournament.registration_open?).to be(true)
    end

    it 'returns false for other statuses' do
      tournament = build(:tournament, status: 'draft')
      expect(tournament.registration_open?).to be(false)
    end
  end

  describe '#slots_available?' do
    let(:tournament) { create(:tournament, max_teams: 2) }

    it 'returns true when enrolled count is below max' do
      expect(tournament.slots_available?).to be(true)
    end

    it 'returns false when all slots are taken' do
      create_list(:tournament_team, 2, :approved, tournament: tournament)
      expect(tournament.slots_available?).to be(false)
    end
  end

  describe '#bracket_generated?' do
    let(:tournament) { create(:tournament) }

    it 'returns false before bracket generation' do
      expect(tournament.bracket_generated?).to be(false)
    end

    it 'returns true after bracket is created' do
      create(:tournament_match, tournament: tournament)
      expect(tournament.bracket_generated?).to be(true)
    end
  end
end
