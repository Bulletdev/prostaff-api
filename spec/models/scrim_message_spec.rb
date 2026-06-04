# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScrimMessage, type: :model do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }
  let(:scrim)        { create(:scrim, organization: organization) }

  describe 'associations' do
    it { is_expected.to belong_to(:scrim) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:organization) }
  end

  describe 'validations' do
    subject { build(:scrim_message, scrim: scrim, user: user, organization: organization) }

    it { is_expected.to validate_presence_of(:content) }

    it 'rejects content exceeding 1000 characters' do
      msg = build(:scrim_message, scrim: scrim, user: user, organization: organization,
                   content: 'x' * 1001)
      expect(msg).not_to be_valid
      expect(msg.errors[:content]).to be_present
    end

    it 'accepts content at exactly 1000 characters' do
      msg = build(:scrim_message, scrim: scrim, user: user, organization: organization,
                   content: 'x' * 1000)
      expect(msg).to be_valid
    end

    it 'rejects blank content' do
      msg = build(:scrim_message, scrim: scrim, user: user, organization: organization, content: '')
      expect(msg).not_to be_valid
    end
  end

  describe '#soft_delete!' do
    it 'marks the message as deleted without destroying the record' do
      msg = create(:scrim_message, scrim: scrim, user: user, organization: organization)

      expect { msg.soft_delete! }.not_to change(ScrimMessage, :count)
      expect(msg.reload.deleted).to be(true)
      expect(msg.deleted_at).to be_within(2.seconds).of(Time.current)
    end
  end

  describe 'scopes' do
    let!(:active_msg)  { create(:scrim_message, scrim: scrim, user: user, organization: organization) }
    let!(:deleted_msg) { create(:scrim_message, :deleted, scrim: scrim, user: user, organization: organization) }

    describe '.active' do
      it 'returns non-deleted messages' do
        expect(ScrimMessage.active).to include(active_msg)
        expect(ScrimMessage.active).not_to include(deleted_msg)
      end
    end

    describe '.chronological' do
      it 'orders messages by created_at ascending' do
        ordered = ScrimMessage.where(scrim: scrim).chronological
        expect(ordered.first.created_at).to be <= ordered.last.created_at
      end
    end
  end

  describe 'MAX_CONTENT_LENGTH' do
    it 'is 1000' do
      expect(ScrimMessage::MAX_CONTENT_LENGTH).to eq(1000)
    end
  end
end
