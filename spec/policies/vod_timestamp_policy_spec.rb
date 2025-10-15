require 'rails_helper'

RSpec.describe VodTimestampPolicy, type: :policy do
  subject { described_class.new(user, vod_timestamp) }

  let(:organization) { create(:organization) }
  let(:vod_review) { create(:vod_review, organization: organization) }
  let(:vod_timestamp) { create(:vod_timestamp, vod_review: vod_review) }

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

  context 'for an analyst' do
    let(:user) { create(:user, :analyst, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should_not permit_action(:destroy) }
  end

  context 'for a viewer' do
    let(:user) { create(:user, :viewer, organization: organization) }

    it { should_not permit_action(:index) }
    it { should_not permit_action(:show) }
    it { should_not permit_action(:create) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
  end

  context 'for a user from different organization' do
    let(:other_organization) { create(:organization) }
    let(:user) { create(:user, :admin, organization: other_organization) }

    it { should_not permit_action(:show) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
  end

  describe 'Scope' do
    let!(:user) { create(:user, :analyst, organization: organization) }
    let!(:timestamp1) { create(:vod_timestamp, vod_review: vod_review) }
    let!(:timestamp2) { create(:vod_timestamp, vod_review: vod_review) }
    let!(:other_vod_review) { create(:vod_review, organization: create(:organization)) }
    let!(:other_timestamp) { create(:vod_timestamp, vod_review: other_vod_review) }

    it 'includes timestamps from user organization' do
      scope = described_class::Scope.new(user, VodTimestamp).resolve
      expect(scope).to include(timestamp1, timestamp2)
      expect(scope).not_to include(other_timestamp)
    end

    context 'for viewers' do
      let!(:viewer) { create(:user, :viewer, organization: organization) }

      it 'excludes timestamps for viewers' do
        scope = described_class::Scope.new(viewer, VodTimestamp).resolve
        expect(scope).to be_empty
      end
    end
  end
end
