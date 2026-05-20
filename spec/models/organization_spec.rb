# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organization, type: :model do
  subject { build(:organization) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }

    it 'rejects invalid region' do
      org = build(:organization, region: 'INVALID')
      expect(org).not_to be_valid
      expect(org.errors[:region]).to be_present
    end

    it 'accepts all valid regions' do
      Constants::REGIONS.each do |region|
        org = build(:organization, region: region)
        expect(org).to be_valid, "expected region #{region} to be valid"
      end
    end

    it 'rejects invalid tier' do
      org = build(:organization, tier: 'invalid_tier')
      expect(org).not_to be_valid
    end

    it 'accepts blank tier' do
      org = build(:organization, tier: nil)
      expect(org).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:users).dependent(:destroy) }
    it { is_expected.to have_many(:players).dependent(:destroy) }
    it { is_expected.to have_many(:matches).dependent(:destroy) }
    it { is_expected.to have_many(:scrims).dependent(:destroy) }
    it { is_expected.to have_many(:competitive_matches).dependent(:destroy) }
    it { is_expected.to have_many(:messages).dependent(:destroy) }
  end

  describe 'slug generation' do
    it 'generates a slug from name on create' do
      org = create(:organization, name: 'Test Team Alpha')
      expect(org.slug).to be_present
    end

    it 'does not override a manually set slug' do
      org = create(:organization, name: 'My Org', slug: 'custom-slug')
      expect(org.slug).to eq('custom-slug')
    end

    it 'generates a unique slug with counter when collision exists' do
      create(:organization, name: 'Same Name', slug: 'same-name')
      org2 = create(:organization, name: 'Same Name')
      expect(org2.slug).to match(/same-name-\d+/)
    end
  end

  describe 'trial management' do
    let(:org) { create(:organization) }

    it 'sets trial period for new organizations' do
      expect(org.subscription_status).to eq('trial')
      expect(org.trial_expires_at).to be_present
    end

    describe '#on_trial?' do
      it 'returns true when trial is active' do
        expect(org.on_trial?).to be(true)
      end

      it 'returns false when trial has expired' do
        org.update_columns(trial_expires_at: 1.day.ago)
        expect(org.on_trial?).to be(false)
      end
    end

    describe '#trial_expired?' do
      it 'returns false for active trial' do
        expect(org.trial_expired?).to be(false)
      end

      it 'returns true when trial has expired' do
        org.update_columns(trial_expires_at: 1.day.ago)
        expect(org.trial_expired?).to be(true)
      end
    end

    describe '#trial_days_remaining' do
      it 'returns a positive integer for active trials' do
        expect(org.trial_days_remaining).to be > 0
      end

      it 'returns 0 when not on trial' do
        org.update_columns(subscription_status: 'active')
        expect(org.trial_days_remaining).to eq(0)
      end
    end

    describe '#has_active_access?' do
      it 'returns true when on active trial' do
        expect(org.has_active_access?).to be(true)
      end

      it 'returns true with active subscription' do
        org.update_columns(subscription_status: 'active')
        expect(org.has_active_access?).to be(true)
      end

      it 'returns false when subscription has expired' do
        org.update_columns(subscription_status: 'expired')
        expect(org.has_active_access?).to be(false)
      end
    end
  end
end
