# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VodTimestampPolicy, type: :policy do
  subject { described_class.new(user, vod_timestamp) }

  let(:organization) { create(:organization) }
  let(:vod_review) { create(:vod_review, organization: organization) }
  let(:vod_timestamp) { create(:vod_timestamp, vod_review: vod_review) }

  # NOTE: VodTimestampPolicy does not define show? — falls back to ApplicationPolicy (false)
  # show? is intentionally not permitted; clients use index? to list all timestamps

  context 'for an owner' do
    let(:user) { create(:user, :owner, organization: organization) }

    it { should_not permit_action(:show) }
    it { should permit_action(:index) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
  end

  context 'for an admin' do
    let(:user) { create(:user, :admin, organization: organization) }

    it { should_not permit_action(:show) }
    it { should permit_action(:index) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
  end

  context 'for a coach' do
    let(:user) { create(:user, :coach, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
  end

  context 'for an analyst' do
    let(:user) { create(:user, :analyst, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
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
end
