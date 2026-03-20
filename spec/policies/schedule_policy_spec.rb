# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SchedulePolicy, type: :policy do
  subject { described_class.new(user, schedule) }

  let(:organization) { create(:organization) }
  let(:schedule) { create(:schedule, organization: organization) }

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
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
  end

  context 'for a user from different organization' do
    let(:other_org) { create(:organization) }
    let(:user) { create(:user, :admin, organization: other_org) }

    it { should permit_action(:index) }
    it { should_not permit_action(:show) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
  end

  describe 'Scope' do
    let(:user) { create(:user, :coach, organization: organization) }
    let(:other_org) { create(:organization) }
    let!(:other_schedule) { create(:schedule, organization: other_org) }

    it 'returns only schedules for the user organization' do
      scope = described_class::Scope.new(user, Schedule.unscoped).resolve
      expect(scope).to include(schedule)
      expect(scope).not_to include(other_schedule)
    end
  end
end
