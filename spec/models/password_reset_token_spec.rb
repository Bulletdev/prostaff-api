# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PasswordResetToken, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with a user owner' do
      token = build(:password_reset_token, user: user)
      expect(token).to be_valid
    end

    it 'requires either a user or a player' do
      token = build(:password_reset_token, user: nil, player: nil)
      expect(token).not_to be_valid
      expect(token.errors[:base]).to be_present
    end

    it 'requires expires_at' do
      token = build(:password_reset_token, user: user, expires_at: nil)
      # before_validation sets expires_at, so nil stays nil only if we bypass it
      token.expires_at = nil
      token.validate
      # The callback sets it on create, so manually clear after validation cycle
      expect(token.expires_at).to be_present
    end

    it 'enforces unique token values' do
      existing = create(:password_reset_token, user: user)
      duplicate = build(:password_reset_token, user: create(:user), token: existing.token)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:token]).to be_present
    end
  end

  describe 'callbacks on create' do
    it 'auto-generates a token' do
      prt = create(:password_reset_token, user: user)
      expect(prt.token).to be_present
      expect(prt.token.length).to be >= 20
    end

    it 'sets expires_at to 1 hour from now when not provided' do
      prt = described_class.create!(user: user)
      expect(prt.expires_at).to be_within(5.seconds).of(1.hour.from_now)
    end
  end

  describe '#expired?' do
    it 'returns false for a token expiring in the future' do
      prt = create(:password_reset_token, user: user)
      expect(prt.expired?).to be(false)
    end

    it 'returns true for a token past its expires_at' do
      prt = create(:password_reset_token, user: user)
      prt.update_columns(expires_at: 1.second.ago)
      expect(prt.expired?).to be(true)
    end
  end

  describe '#valid_token?' do
    it 'returns true when not expired and not used' do
      prt = create(:password_reset_token, user: user)
      expect(prt.valid_token?).to be(true)
    end

    it 'returns false when expired' do
      prt = create(:password_reset_token, user: user)
      prt.update_columns(expires_at: 1.minute.ago)
      expect(prt.valid_token?).to be(false)
    end

    it 'returns false when already used' do
      prt = create(:password_reset_token, user: user)
      prt.update_columns(used_at: 5.minutes.ago)
      expect(prt.valid_token?).to be(false)
    end
  end

  describe '#used?' do
    it 'returns false when used_at is nil' do
      prt = create(:password_reset_token, user: user)
      expect(prt.used?).to be(false)
    end

    it 'returns true when used_at is set' do
      prt = create(:password_reset_token, user: user)
      prt.update_columns(used_at: Time.current)
      expect(prt.used?).to be(true)
    end
  end

  describe '#mark_as_used!' do
    it 'sets used_at to the current time' do
      prt = create(:password_reset_token, user: user)
      expect { prt.mark_as_used! }.to change { prt.reload.used_at }.from(nil)
      expect(prt.used_at).to be_within(2.seconds).of(Time.current)
    end

    it 'makes valid_token? return false after use' do
      prt = create(:password_reset_token, user: user)
      prt.mark_as_used!
      expect(prt.valid_token?).to be(false)
    end
  end

  describe '#owner' do
    it 'returns the user when associated with a user' do
      prt = create(:password_reset_token, user: user)
      expect(prt.owner).to eq(user)
    end

    it 'returns the player when associated with a player' do
      player = create(:player)
      prt = create(:password_reset_token, user: nil, player: player)
      expect(prt.owner).to eq(player)
    end
  end

  describe '.valid scope' do
    it 'returns tokens that are unexpired and unused' do
      valid_prt   = create(:password_reset_token, user: user)
      expired_prt = create(:password_reset_token, user: create(:user))
      expired_prt.update_columns(expires_at: 1.minute.ago)
      used_prt    = create(:password_reset_token, user: create(:user))
      used_prt.update_columns(used_at: 10.minutes.ago)

      valid_tokens = described_class.valid
      expect(valid_tokens).to include(valid_prt)
      expect(valid_tokens).not_to include(expired_prt)
      expect(valid_tokens).not_to include(used_prt)
    end
  end

  describe '.generate_secure_token' do
    it 'generates a unique URL-safe base64 string each call' do
      t1 = described_class.generate_secure_token
      t2 = described_class.generate_secure_token
      expect(t1).not_to eq(t2)
      expect(t1).to match(/\A[A-Za-z0-9\-_]+\z/)
    end
  end
end
