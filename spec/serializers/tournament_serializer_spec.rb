# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TournamentSerializer do
  let(:tournament) { create(:tournament) }

  subject(:result) { described_class.new(tournament).as_json }

  it 'exposes identifier' do
    expect(result[:id]).to eq(tournament.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :name, :game, :format, :status, :max_teams,
      :enrolled_teams_count, :slots_available, :bracket_generated,
      :bo_format, :current_round_label, :rules
    )
  end

  it 'exposes fee fields' do
    expect(result).to include(:entry_fee_cents, :prize_pool_cents)
  end

  it 'exposes schedule fields' do
    expect(result).to include(
      :registration_closes_at, :scheduled_start_at,
      :started_at, :finished_at, :created_at
    )
  end

  describe 'status field' do
    it 'is a valid lifecycle status' do
      expect(result[:status]).to be_in(
        %w[draft registration_open seeding in_progress finished]
      )
    end

    context 'when registration_open' do
      it 'is registration_open' do
        expect(result[:status]).to eq('registration_open')
      end
    end
  end

  describe 'format field' do
    it 'is a valid tournament format' do
      expect(result[:format]).to be_in(%w[single_elimination double_elimination])
    end
  end

  describe 'enrolled_teams_count field' do
    it 'is a non-negative integer' do
      expect(result[:enrolled_teams_count]).to be_a(Integer)
      expect(result[:enrolled_teams_count]).to be >= 0
    end
  end

  describe 'slots_available field' do
    it 'is a boolean' do
      expect(result[:slots_available]).to be_in([true, false])
    end
  end

  describe 'bracket_generated field' do
    it 'is a boolean' do
      expect(result[:bracket_generated]).to be_in([true, false])
    end
  end

  describe 'with_bracket option' do
    context 'without with_bracket' do
      it 'does not include matches key' do
        expect(result).not_to have_key(:matches)
      end
    end

    context 'with with_bracket: true' do
      subject(:bracket_result) { described_class.new(tournament, with_bracket: true).as_json }

      it 'includes matches as an array' do
        expect(bracket_result[:matches]).to be_an(Array)
      end
    end
  end

  describe 'finished tournament' do
    let(:tournament) { create(:tournament, :finished) }

    it 'has status finished' do
      expect(result[:status]).to eq('finished')
    end

    it 'has a finished_at timestamp' do
      expect(result[:finished_at]).to be_present
    end
  end
end
