# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeamGoalPolicy, type: :policy do
  subject { described_class.new(user, team_goal) }

  let(:organization) { create(:organization) }
  let(:team_goal) { create(:team_goal, organization: organization) }

  context 'for an owner' do
    let(:user) { create(:user, :owner, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
  end

  context 'for an admin' do
    let(:user) { create(:user, :admin, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
  end

  context 'for a coach' do
    let(:user) { create(:user, :coach, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should_not permit_action(:destroy) }
  end

  context 'for a viewer' do
    let(:user) { create(:user, :viewer, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should_not permit_action(:create) }
    it { should_not permit_action(:destroy) }
  end

  context 'for a user updating a goal assigned to them' do
    let(:user) { create(:user, :viewer, organization: organization) }
    let(:team_goal) { create(:team_goal, organization: organization, assigned_to_id: user.id) }

    it { should permit_action(:update) }
  end

  context 'for a user from different organization' do
    let(:other_org) { create(:organization) }
    let(:user) { create(:user, :admin, organization: other_org) }

    it { should_not permit_action(:show) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
  end

  describe 'Scope' do
    let(:user) { create(:user, :admin, organization: organization) }
    let(:other_org) { create(:organization) }
    let!(:other_goal) { create(:team_goal, organization: other_org) }

    it 'returns only goals for the user organization' do
      scope = described_class::Scope.new(user, TeamGoal.unscoped).resolve
      expect(scope).to include(team_goal)
      expect(scope).not_to include(other_goal)
    end
  end
end
