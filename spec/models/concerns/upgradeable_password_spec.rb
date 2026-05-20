# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpgradeablePassword, type: :model do
  let(:password) { 'Test123!@#' }

  describe 'User#authenticate (argon2id path)' do
    let(:user) { create(:user, password: password) }

    it 'returns the user for the correct password' do
      expect(user.authenticate(password)).to eq(user)
    end

    it 'returns nil for a wrong password' do
      expect(user.authenticate('WrongPass1')).to be_nil
    end

    it 'does not modify the digest when already argon2id' do
      original = user.password_digest
      user.authenticate(password)
      expect(user.reload.password_digest).to eq(original)
    end
  end

  describe 'User#authenticate — bcrypt to argon2id lazy migration' do
    let(:user) { create(:user, password: password) }
    let(:bcrypt_digest) { BCrypt::Password.create(password, cost: BCrypt::Engine::MIN_COST).to_s }

    before { user.update_column(:password_digest, bcrypt_digest) }

    it 'authenticates successfully against a bcrypt digest' do
      expect(user.authenticate(password)).to eq(user)
    end

    it 'upgrades the digest to argon2id transparently after successful login' do
      user.authenticate(password)
      expect(user.reload.password_digest).to start_with('$argon2id$')
    end

    it 'updates updated_at alongside the digest upgrade' do
      before = user.updated_at
      user.authenticate(password)
      expect(user.reload.updated_at).to be >= before
    end

    it 'does not upgrade the digest when the password is wrong' do
      user.authenticate('WrongPass1')
      expect(user.reload.password_digest).to eq(bcrypt_digest)
    end
  end

  describe 'Player#authenticate_player_password — bcrypt to argon2id lazy migration' do
    let(:player) do
      create(:player).tap do |p|
        argon2_digest = Authentication::PasswordHasher.hash(password)
        p.update_column(:player_password_digest, argon2_digest)
      end
    end
    let(:bcrypt_digest) { BCrypt::Password.create(password, cost: BCrypt::Engine::MIN_COST).to_s }

    before { player.update_column(:player_password_digest, bcrypt_digest) }

    it 'authenticates successfully against a bcrypt digest' do
      expect(player.authenticate_player_password(password)).to eq(player)
    end

    it 'upgrades the digest to argon2id transparently after successful login' do
      player.authenticate_player_password(password)
      expect(player.reload.player_password_digest).to start_with('$argon2id$')
    end

    it 'does not upgrade the digest when the password is wrong' do
      player.authenticate_player_password('WrongPass1')
      expect(player.reload.player_password_digest).to eq(bcrypt_digest)
    end
  end
end
