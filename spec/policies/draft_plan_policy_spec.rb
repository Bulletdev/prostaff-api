# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DraftPlanPolicy, type: :policy do
  subject { described_class.new(user, draft_plan) }

  let(:organization) { create(:organization) }
  let(:draft_plan) { create(:draft_plan, organization: organization) }

  context 'for an owner' do
    let(:user) { create(:user, :owner, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
    it { should permit_action(:analyze) }
    it { should permit_action(:activate) }
    it { should permit_action(:deactivate) }
  end

  context 'for an admin' do
    let(:user) { create(:user, :admin, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
    it { should permit_action(:analyze) }
    it { should permit_action(:activate) }
    it { should permit_action(:deactivate) }
  end

  context 'for a coach' do
    let(:user) { create(:user, :coach, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should permit_action(:analyze) }
    it { should permit_action(:activate) }
    it { should permit_action(:deactivate) }
  end

  context 'for a viewer' do
    let(:user) { create(:user, :viewer, organization: organization) }

    it { should_not permit_action(:index) }
    it { should_not permit_action(:show) }
    it { should_not permit_action(:create) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should_not permit_action(:analyze) }
    it { should_not permit_action(:activate) }
    it { should_not permit_action(:deactivate) }
  end

  context 'for a user from different organization' do
    let(:other_org) { create(:organization) }
    let(:user) { create(:user, :coach, organization: other_org) }

    it { should_not permit_action(:show) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should_not permit_action(:analyze) }
    it { should_not permit_action(:activate) }
    it { should_not permit_action(:deactivate) }
  end

  describe 'Scope' do
    let(:user) { create(:user, :coach, organization: organization) }
    let(:other_org) { create(:organization) }
    let!(:other_plan) { create(:draft_plan, organization: other_org) }

    it 'returns only draft plans for the user organization' do
      scope = described_class::Scope.new(user, DraftPlan.unscoped).resolve
      expect(scope).to include(draft_plan)
      expect(scope).not_to include(other_plan)
    end

    context 'for a viewer' do
      let(:user) { create(:user, :viewer, organization: organization) }

      it 'returns no draft plans' do
        scope = described_class::Scope.new(user, DraftPlan.unscoped).resolve
        expect(scope).to be_empty
      end
    end
  end
end
