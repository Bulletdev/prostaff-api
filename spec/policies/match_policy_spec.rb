# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatchPolicy, type: :policy do
  subject { described_class.new(user, match) }

  let(:organization) { create(:organization) }
  let(:match) { create(:match, organization: organization) }

  context 'for an owner' do
    let(:user) { create(:user, :owner, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
    it { should permit_action(:stats) }
    it { should permit_action(:import) }
  end

  context 'for an admin' do
    let(:user) { create(:user, :admin, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
    it { should permit_action(:stats) }
    it { should permit_action(:import) }
  end

  context 'for a coach' do
    let(:user) { create(:user, :coach, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should permit_action(:import) }
  end

  context 'for a viewer' do
    let(:user) { create(:user, :viewer, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should_not permit_action(:create) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should_not permit_action(:import) }
  end

  context 'for a user from different organization' do
    let(:other_org) { create(:organization) }
    let(:user) { create(:user, :admin, organization: other_org) }

    it { should permit_action(:index) }
    it { should_not permit_action(:show) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should_not permit_action(:stats) }
    it { should_not permit_action(:import) }
  end

  describe 'Scope' do
    let(:user) { create(:user, :admin, organization: organization) }
    let(:other_org) { create(:organization) }
    let!(:other_match) { create(:match, organization: other_org) }

    it 'returns only matches for the user organization' do
      scope = described_class::Scope.new(user, Match.unscoped).resolve
      expect(scope).to include(match)
      expect(scope).not_to include(other_match)
    end
  end
end
