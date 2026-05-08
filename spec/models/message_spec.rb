# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:organization) }
    it { should belong_to(:recipient).class_name('User').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:content) }
    it { should validate_length_of(:content).is_at_least(1).is_at_most(2000) }
  end

  describe 'scopes' do
    let(:org)  { create(:organization) }
    let(:user) { create(:user, organization: org) }
    let!(:active_msg)  { create(:message, organization: org, user: user, deleted: false) }
    let!(:deleted_msg) { create(:message, organization: org, user: user, deleted: true, deleted_at: Time.current) }

    describe '.active' do
      it 'returns only non-deleted messages' do
        expect(Message.active).to include(active_msg)
        expect(Message.active).not_to include(deleted_msg)
      end
    end

    describe '.for_organization' do
      let(:other_org) { create(:organization) }
      let(:other_user) { create(:user, organization: other_org) }
      let!(:other_msg) { create(:message, organization: other_org, user: other_user) }

      it 'returns only messages of the given org' do
        results = Message.for_organization(org.id)
        expect(results).to include(active_msg)
        expect(results).not_to include(other_msg)
      end
    end
  end

  describe '.dm_stream_key' do
    it 'produces the same key regardless of user order' do
      org = create(:organization)
      user_a = create(:user, organization: org)
      user_b = create(:user, organization: org)
      key_ab = Message.dm_stream_key(user_a.id, user_b.id, org.id)
      key_ba = Message.dm_stream_key(user_b.id, user_a.id, org.id)
      expect(key_ab).to eq(key_ba)
    end

    it 'includes the org_id in the key' do
      org = create(:organization)
      user_a = create(:user, organization: org)
      user_b = create(:user, organization: org)
      key = Message.dm_stream_key(user_a.id, user_b.id, org.id)
      expect(key).to include(org.id.to_s)
    end
  end

  describe '#soft_delete!' do
    let(:org)  { create(:organization) }
    let(:user) { create(:user, organization: org) }
    let(:msg)  { create(:message, organization: org, user: user) }

    it 'sets deleted to true' do
      msg.soft_delete!
      expect(msg.reload.deleted).to be true
    end

    it 'sets deleted_at timestamp' do
      msg.soft_delete!
      expect(msg.reload.deleted_at).to be_present
    end
  end

  describe 'cross-org recipient validation' do
    let(:org_a)   { create(:organization) }
    let(:org_b)   { create(:organization) }
    let(:user_a)  { create(:user, organization: org_a) }
    let(:user_b)  { create(:user, organization: org_b) }

    it 'is invalid when recipient belongs to a different org' do
      msg = build(:message, organization: org_a, user: user_a, recipient: user_b)
      expect(msg).not_to be_valid
      expect(msg.errors[:recipient]).to be_present
    end

    it 'is valid when recipient belongs to the same org' do
      user_b_same_org = create(:user, organization: org_a)
      msg = build(:message, organization: org_a, user: user_a, recipient: user_b_same_org)
      expect(msg).to be_valid
    end
  end
end
