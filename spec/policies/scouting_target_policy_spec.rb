# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScoutingTargetPolicy, type: :policy do
  # ScoutingTarget is GLOBAL — no organization_id.
  # All coach+ users can view/create/update all targets.
  # Only admins can delete.
  let(:organization) { create(:organization) }

  # Use a plain struct as record since ScoutingTarget has no organization_id
  let(:record) { double('ScoutingTarget') }

  context 'for an owner' do
    subject { described_class.new(create(:user, :owner, organization: organization), record) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
    it { should permit_action(:sync) }
  end

  context 'for an admin' do
    subject { described_class.new(create(:user, :admin, organization: organization), record) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
    it { should permit_action(:sync) }
  end

  context 'for a coach' do
    subject { described_class.new(create(:user, :coach, organization: organization), record) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should permit_action(:sync) }
  end

  context 'for a viewer' do
    subject { described_class.new(create(:user, :viewer, organization: organization), record) }

    it { should_not permit_action(:index) }
    it { should_not permit_action(:show) }
    it { should_not permit_action(:create) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should_not permit_action(:sync) }
  end

  describe 'Scope' do
    context 'for a coach' do
      let(:user) { create(:user, :coach, organization: organization) }

      it 'returns all scouting targets (global resource)' do
        scope = described_class::Scope.new(user, ScoutingTarget).resolve
        expect(scope).to eq(ScoutingTarget.all)
      end
    end

    context 'for a viewer' do
      let(:user) { create(:user, :viewer, organization: organization) }

      it 'returns no scouting targets' do
        scope = described_class::Scope.new(user, ScoutingTarget).resolve
        expect(scope).to eq(ScoutingTarget.none)
      end
    end
  end
end
