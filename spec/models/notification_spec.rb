# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notification, type: :model do
  let(:org)  { create(:organization) }
  let(:user) { create(:user, organization: org) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(200) }
    it { should validate_presence_of(:message) }
    it { should validate_presence_of(:type) }

    it 'is invalid with an unknown type' do
      n = build(:notification, user: user, type: 'unknown_type')
      expect(n).not_to be_valid
    end

    it 'is valid with each allowed type' do
      %w[info success warning error match schedule system].each do |t|
        n = build(:notification, user: user, type: t)
        expect(n).to be_valid, "expected #{t} to be valid"
      end
    end
  end

  describe 'scopes' do
    let!(:unread_n) { create(:notification, user: user, is_read: false) }
    let!(:read_n)   { create(:notification, :read, user: user) }

    describe '.unread' do
      it 'returns only unread notifications' do
        expect(Notification.unread).to include(unread_n)
        expect(Notification.unread).not_to include(read_n)
      end
    end

    describe '.read' do
      it 'returns only read notifications' do
        expect(Notification.read).to include(read_n)
        expect(Notification.read).not_to include(unread_n)
      end
    end
  end

  describe '#mark_as_read!' do
    let(:notification) { create(:notification, user: user, is_read: false) }

    it 'sets is_read to true' do
      notification.mark_as_read!
      expect(notification.reload.is_read).to be true
    end

    it 'sets read_at timestamp' do
      notification.mark_as_read!
      expect(notification.reload.read_at).to be_present
    end
  end

  describe '#unread?' do
    it 'returns true when not read' do
      n = build(:notification, user: user, is_read: false)
      expect(n.unread?).to be true
    end

    it 'returns false when already read' do
      n = build(:notification, :read, user: user)
      expect(n.unread?).to be false
    end
  end

  describe 'default channels callback' do
    it 'sets channels to [in_app] when not provided' do
      n = create(:notification, user: user)
      expect(n.channels).to include('in_app')
    end
  end
end
