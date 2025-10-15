require 'rails_helper'

RSpec.describe VodReviewPolicy, type: :policy do
  subject { described_class.new(user, vod_review) }

  let(:organization) { create(:organization) }
  let(:vod_review) { create(:vod_review, organization: organization) }

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
    let!(:vod_review1) { create(:vod_review, organization: organization) }
    let!(:vod_review2) { create(:vod_review, organization: organization) }
    let!(:other_vod_review) { create(:vod_review, organization: create(:organization)) }

    it 'includes vod reviews from user organization' do
      scope = described_class::Scope.new(user, VodReview).resolve
      expect(scope).to include(vod_review1, vod_review2)
      expect(scope).not_to include(other_vod_review)
    end

    context 'for viewers' do
      let!(:viewer) { create(:user, :viewer, organization: organization) }

      it 'excludes vod reviews for viewers' do
        scope = described_class::Scope.new(viewer, VodReview).resolve
        expect(scope).to be_empty
      end
    end
  end
end
