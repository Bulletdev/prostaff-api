# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GoalCheckIn, type: :model do
  let(:org)  { create(:organization) }
  let(:goal) { create(:team_goal, organization: org) }

  def build_check_in(overrides = {})
    build(:goal_check_in, { team_goal: goal, organization: org }.merge(overrides))
  end

  describe 'associations' do
    it { should belong_to(:team_goal) }
    it { should belong_to(:organization) }
    it { should belong_to(:created_by).optional }
  end

  describe 'validations' do
    it 'is valid with source auto' do
      expect(build_check_in(source: 'auto')).to be_valid
    end

    it 'is valid with source manual' do
      expect(build_check_in(source: 'manual')).to be_valid
    end

    it 'is invalid with unknown source' do
      check_in = build_check_in(source: 'robot')
      expect(check_in).not_to be_valid
      expect(check_in.errors[:source]).to be_present
    end

    it 'requires organization_id' do
      check_in = build_check_in
      check_in.organization_id = nil
      expect(check_in).not_to be_valid
    end
  end

  describe 'scopes' do
    before do
      create(:goal_check_in, team_goal: goal, organization: org, source: 'auto')
      create(:goal_check_in, team_goal: goal, organization: org, source: 'manual')
    end

    it '.auto_generated returns only auto records' do
      expect(GoalCheckIn.auto_generated.map(&:source).uniq).to eq(['auto'])
    end

    it '.manual_entries returns only manual records' do
      expect(GoalCheckIn.manual_entries.map(&:source).uniq).to eq(['manual'])
    end
  end
end
