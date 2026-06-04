# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationSerializer do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:notification) { create(:notification, user: user) }

  subject(:result) { described_class.render_as_hash(notification) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(notification.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :title, :message, :type, :is_read,
      :created_at, :updated_at
    )
  end

  it 'exposes link fields' do
    expect(result).to include(:link_url, :link_type, :link_id)
  end

  it 'exposes delivery channel fields' do
    expect(result).to include(:channels, :email_sent, :discord_sent)
  end

  describe 'is_read field' do
    context 'when unread' do
      let(:notification) { create(:notification, user: user) }

      it 'is false' do
        expect(result[:is_read]).to be(false)
      end
    end

    context 'when read' do
      let(:notification) { create(:notification, :read, user: user) }

      it 'is true' do
        expect(result[:is_read]).to be(true)
      end
    end
  end

  describe 'time_ago field' do
    it 'is a string' do
      expect(result[:time_ago]).to be_a(String)
    end

    context 'when notification was just created' do
      it 'includes seconds' do
        expect(result[:time_ago]).to match(/seconds ago/)
      end
    end
  end

  describe 'user association' do
    it 'includes the associated user id' do
      expect(result[:user][:id]).to eq(user.id)
    end

    it 'does not expose password_digest in user association' do
      expect(result[:user].keys).not_to include(:password_digest, :jti)
    end
  end
end
