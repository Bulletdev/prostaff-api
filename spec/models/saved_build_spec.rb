# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedBuild, type: :model do
  let(:org) { create(:organization) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:created_by).class_name('User').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:champion) }
    it { should validate_numericality_of(:games_played).is_greater_than_or_equal_to(0) }

    it 'is invalid with unknown data_source' do
      b = build(:saved_build, organization: org, data_source: 'scraped')
      expect(b).not_to be_valid
    end

    it 'is invalid with an unknown LoL role' do
      b = build(:saved_build, organization: org, role: 'carry')
      expect(b).not_to be_valid
    end

    it 'is valid with each LoL role' do
      %w[top jungle mid adc support].each do |role|
        b = build(:saved_build, organization: org, role: role)
        expect(b).to be_valid, "expected #{role} to be valid"
      end
    end

    it 'is invalid when win_rate > 100' do
      b = build(:saved_build, organization: org, win_rate: 101.0)
      expect(b).not_to be_valid
    end

    it 'is invalid when win_rate < 0' do
      b = build(:saved_build, organization: org, win_rate: -1.0)
      expect(b).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:jinx_build)   { create(:saved_build, organization: org, champion: 'Jinx',  role: 'adc',    win_rate: 62.0) }
    let!(:thresh_build) { create(:saved_build, organization: org, champion: 'Thresh', role: 'support', win_rate: 55.0) }
    let!(:manual_build) { create(:saved_build, organization: org, data_source: 'manual') }
    let!(:agg_build)    { create(:saved_build, :aggregated, organization: org) }

    describe '.by_champion' do
      it 'filters by champion' do
        expect(SavedBuild.by_champion('Jinx')).to include(jinx_build)
        expect(SavedBuild.by_champion('Jinx')).not_to include(thresh_build)
      end
    end

    describe '.by_role' do
      it 'filters by role' do
        expect(SavedBuild.by_role('adc')).to include(jinx_build)
        expect(SavedBuild.by_role('adc')).not_to include(thresh_build)
      end
    end

    describe '.ranked_by_win_rate' do
      it 'orders by win_rate descending' do
        ordered = SavedBuild.where(organization: org).ranked_by_win_rate
        win_rates = ordered.map(&:win_rate).compact
        expect(win_rates).to eq(win_rates.sort.reverse)
      end
    end

    describe '.manual' do
      it 'returns only manual builds' do
        expect(SavedBuild.manual).to include(manual_build)
        expect(SavedBuild.manual).not_to include(agg_build)
      end
    end

    describe '.aggregated' do
      it 'returns only aggregated builds' do
        expect(SavedBuild.aggregated).to include(agg_build)
        expect(SavedBuild.aggregated).not_to include(manual_build)
      end
    end
  end

  describe '#manual? and #aggregated?' do
    it 'returns true for manual?' do
      b = build(:saved_build, organization: org, data_source: 'manual')
      expect(b.manual?).to be true
      expect(b.aggregated?).to be false
    end

    it 'returns true for aggregated?' do
      b = build(:saved_build, :aggregated, organization: org)
      expect(b.aggregated?).to be true
      expect(b.manual?).to be false
    end
  end

  describe '#win_rate_display' do
    it 'formats win_rate with % suffix' do
      b = build(:saved_build, organization: org, win_rate: 62.5)
      expect(b.win_rate_display).to eq('62.5%')
    end
  end
end
