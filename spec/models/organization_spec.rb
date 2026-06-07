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

  describe 'tier features (TierFeatures concern)' do
    describe '#can_access?' do
      it 'returns true for a feature available in the org tier' do
        org = create(:organization, tier: 'tier_2_semi_pro')
        expect(org.can_access?('scrims')).to be(true)
      end

      it 'returns false for a feature not available in the org tier' do
        org = create(:organization, tier: 'tier_3_amateur')
        expect(org.can_access?('scrims')).to be(false)
      end
    end

    describe '#can_access_scrims?' do
      it 'returns true for tier_2_semi_pro' do
        org = build(:organization, tier: 'tier_2_semi_pro')
        expect(org.can_access_scrims?).to be(true)
      end

      it 'returns true for tier_1_professional' do
        org = build(:organization, tier: 'tier_1_professional')
        expect(org.can_access_scrims?).to be(true)
      end

      it 'returns false for tier_3_amateur' do
        org = build(:organization, tier: 'tier_3_amateur')
        expect(org.can_access_scrims?).to be(false)
      end
    end

    describe '#can_access_competitive_data?' do
      it 'returns true for tier_1_professional only' do
        expect(build(:organization, tier: 'tier_1_professional').can_access_competitive_data?).to be(true)
        expect(build(:organization, tier: 'tier_2_semi_pro').can_access_competitive_data?).to be(false)
        expect(build(:organization, tier: 'tier_3_amateur').can_access_competitive_data?).to be(false)
      end
    end

    describe '#player_limit_reached?' do
      it 'returns false when player count is below the tier limit' do
        org = create(:organization, tier: 'tier_3_amateur')
        # 0 players, limit is 10 — not reached
        expect(org.player_limit_reached?).to be(false)
      end
    end

    describe '#analytics_level' do
      it 'returns :basic for tier_3_amateur' do
        org = build(:organization, tier: 'tier_3_amateur')
        expect(org.analytics_level).to eq(:basic)
      end

      it 'returns :advanced for tier_2_semi_pro' do
        org = build(:organization, tier: 'tier_2_semi_pro')
        expect(org.analytics_level).to eq(:advanced)
      end

      it 'returns :predictive for tier_1_professional' do
        org = build(:organization, tier: 'tier_1_professional')
        expect(org.analytics_level).to eq(:predictive)
      end
    end

    describe '#tier_display_name' do
      it 'returns human-readable names for each tier' do
        expect(build(:organization, tier: 'tier_3_amateur').tier_display_name).to eq('Amateur (Tier 3)')
        expect(build(:organization, tier: 'tier_2_semi_pro').tier_display_name).to eq('Semi-Pro (Tier 2)')
        expect(build(:organization, tier: 'tier_1_professional').tier_display_name).to eq('Professional (Tier 1)')
      end
    end

    describe '#available_features' do
      it 'returns the feature list for the org tier' do
        org = build(:organization, tier: 'tier_1_professional')
        features = org.available_features
        expect(features).to include('competitive_data', 'predictive_analytics')
      end
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
