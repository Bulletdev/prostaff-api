# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrganizationSerializer do
  let(:organization) { create(:organization) }

  subject(:result) { described_class.render_as_hash(organization) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(organization.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :name, :slug, :region, :tier, :subscription_plan,
      :subscription_status, :logo_url, :settings, :created_at, :updated_at
    )
  end

  it 'includes region_display as a string' do
    expect(result[:region_display]).to be_a(String)
  end

  it 'includes tier_display as a string' do
    expect(result[:tier_display]).to be_a(String)
  end

  it 'includes subscription_display as a string' do
    expect(result[:subscription_display]).to be_a(String)
  end

  describe 'trial_info field' do
    it 'is a hash with required keys' do
      expect(result[:trial_info]).to include(
        :on_trial, :trial_expired, :days_remaining, :has_active_access
      )
    end

    it 'has boolean on_trial flag' do
      expect(result[:trial_info][:on_trial]).to be_in([true, false])
    end
  end

  describe 'statistics field' do
    it 'is a hash with numeric counts' do
      expect(result[:statistics]).to include(
        :total_players, :active_players, :total_matches,
        :recent_matches, :total_users
      )
    end

    it 'has non-negative player counts' do
      expect(result[:statistics][:total_players]).to be >= 0
      expect(result[:statistics][:active_players]).to be >= 0
    end
  end

  describe 'features field' do
    it 'includes access capability flags' do
      expect(result[:features]).to include(
        :can_access_scrims,
        :can_access_competitive_data,
        :can_access_predictive_analytics,
        :available_features,
        :available_data_sources,
        :available_analytics
      )
    end

    it 'has boolean access flags' do
      expect(result[:features][:can_access_scrims]).to be_in([true, false])
    end
  end

  describe 'limits field' do
    it 'includes all limit keys' do
      expect(result[:limits]).to include(
        :max_players, :max_matches_per_month,
        :current_players, :current_monthly_matches,
        :players_remaining, :matches_remaining
      )
    end
  end

  it 'does not expose internal or sensitive fields' do
    expect(result.keys).not_to include(:password_digest, :jti, :encrypted_password)
  end
end
