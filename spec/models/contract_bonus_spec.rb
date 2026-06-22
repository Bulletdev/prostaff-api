# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContractBonus, type: :model do
  let(:org)      { create(:organization) }
  let(:contract) { create(:contract, organization: org) }

  def build_bonus(overrides = {})
    build(:contract_bonus, { contract: contract, organization: org }.merge(overrides))
  end

  describe 'associations' do
    it { should belong_to(:contract) }
    it { should belong_to(:organization) }
  end

  describe 'validations' do
    it { should validate_presence_of(:trigger) }
    it { should validate_presence_of(:amount) }

    it 'is invalid with an unknown bonus_type' do
      bonus = build_bonus(bonus_type: 'invalid')
      expect(bonus).not_to be_valid
    end

    it 'is invalid with amount <= 0' do
      bonus = build_bonus(amount: 0)
      expect(bonus).not_to be_valid
    end

    it 'is invalid with an unknown status' do
      bonus = build_bonus(status: 'nonexistent')
      expect(bonus).not_to be_valid
    end
  end

  describe 'metric_key validation' do
    it 'is valid when metric_key is nil (free-text trigger bonus)' do
      bonus = build_bonus(metric_key: nil)
      expect(bonus).to be_valid
    end

    it 'is valid when metric_key is blank' do
      bonus = build_bonus(metric_key: '')
      expect(bonus).to be_valid
    end

    it 'is valid with a known metric key' do
      bonus = build_bonus(metric_key: 'win_rate')
      expect(bonus).to be_valid
    end

    it 'is invalid with an unknown metric key' do
      bonus = build_bonus(metric_key: 'made_up_metric')
      expect(bonus).not_to be_valid
      expect(bonus.errors[:metric_key]).to be_present
    end

    it 'accepts all keys declared in Goals::MetricRegistry' do
      Goals::MetricRegistry::METRICS.each_key do |key|
        bonus = build_bonus(metric_key: key)
        expect(bonus).to be_valid, "expected registry key #{key} to be valid on ContractBonus"
      end
    end
  end
end
