# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MarketRegistration, type: :model do
  describe 'associations' do
    it { should belong_to(:scouting_target).optional }
  end

  describe 'validations' do
    subject { build(:market_registration) }

    it { should validate_presence_of(:player_external_name) }
    it { should validate_presence_of(:snapshot_date) }

    it 'is valid with leaguepedia_gcd source' do
      record = build(:market_registration, source: 'leaguepedia_gcd')
      expect(record).to be_valid
    end

    it 'is invalid with an unknown source' do
      record = build(:market_registration, source: 'unknown_source')
      expect(record).not_to be_valid
      expect(record.errors[:source]).to be_present
    end
  end

  describe 'scopes' do
    let!(:cblol_player) { create(:market_registration, region: 'CBLOL', snapshot_date: Date.current) }
    let!(:lck_player)   { create(:market_registration, region: 'LCK',   snapshot_date: Date.current) }

    describe '.for_region' do
      it 'returns only records matching the given region' do
        result = described_class.for_region('CBLOL')
        expect(result).to include(cblol_player)
        expect(result).not_to include(lck_player)
      end

      it 'returns all records when region is blank' do
        result = described_class.for_region(nil)
        expect(result).to include(cblol_player, lck_player)
      end

      it 'returns all records when region is empty string' do
        result = described_class.for_region('')
        expect(result).to include(cblol_player, lck_player)
      end
    end

    describe '.expiring_before' do
      let!(:expiring_soon) do
        create(:market_registration, :expiring_soon,
               player_external_name: "expiring_#{SecureRandom.hex(4)}",
               snapshot_date: Date.current)
      end
      let!(:far_future) do
        create(:market_registration,
               player_external_name: "future_#{SecureRandom.hex(4)}",
               contract_end_date: 1.year.from_now.to_date,
               snapshot_date: Date.current)
      end
      let!(:no_contract) do
        create(:market_registration, :no_contract,
               player_external_name: "no_contract_#{SecureRandom.hex(4)}",
               snapshot_date: Date.current)
      end

      it 'returns records with contract_end_date on or before the given date' do
        cutoff = 30.days.from_now.to_date
        result = described_class.expiring_before(cutoff.to_s)
        expect(result).to include(expiring_soon)
        expect(result).not_to include(far_future)
      end

      it 'excludes records with no contract_end_date' do
        cutoff = 1.year.from_now.to_date
        result = described_class.expiring_before(cutoff.to_s)
        expect(result).not_to include(no_contract)
      end

      it 'returns all records when date is nil' do
        result = described_class.expiring_before(nil)
        expect(result).to include(expiring_soon, far_future, no_contract)
      end
    end

    describe '.by_player' do
      it 'orders records by player_external_name ascending' do
        create(:market_registration, player_external_name: 'Zephyr', snapshot_date: Date.current)
        create(:market_registration, player_external_name: 'Alpha',  snapshot_date: Date.current)
        names = described_class.by_player.pluck(:player_external_name)
        expect(names).to eq(names.sort)
      end
    end
  end
end
