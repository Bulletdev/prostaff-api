# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Authentication::PasswordHasher do
  let(:password) { 'Test123!@#' }

  describe '.hash' do
    it 'returns a string with argon2id prefix' do
      expect(described_class.hash(password)).to start_with('$argon2id$')
    end

    it 'produces a different digest on each call due to random salt' do
      expect(described_class.hash(password)).not_to eq(described_class.hash(password))
    end
  end

  describe '.verify' do
    context 'with an argon2id digest' do
      let(:digest) { described_class.hash(password) }

      it 'returns true for the correct password' do
        expect(described_class.verify(password, digest)).to be true
      end

      it 'returns false for a wrong password' do
        expect(described_class.verify('WrongPass1', digest)).to be false
      end
    end

    context 'with a bcrypt digest (legacy retrocompatibility)' do
      let(:digest) { BCrypt::Password.create(password, cost: BCrypt::Engine::MIN_COST) }

      it 'returns true for the correct password' do
        expect(described_class.verify(password, digest)).to be true
      end

      it 'returns false for a wrong password' do
        expect(described_class.verify('WrongPass1', digest)).to be false
      end

      it 'returns false for a malformed bcrypt string' do
        expect(described_class.verify(password, '$2a$not_a_valid_hash')).to be false
      end
    end

    context 'with blank inputs' do
      let(:digest) { described_class.hash(password) }

      it 'returns false when password is blank' do
        expect(described_class.verify('', digest)).to be false
      end

      it 'returns false when digest is blank' do
        expect(described_class.verify(password, '')).to be false
      end

      it 'returns false when both are blank' do
        expect(described_class.verify('', '')).to be false
      end
    end
  end

  describe '.needs_upgrade?' do
    it 'returns true for a bcrypt digest' do
      digest = BCrypt::Password.create(password, cost: BCrypt::Engine::MIN_COST)
      expect(described_class.needs_upgrade?(digest)).to be true
    end

    it 'returns false for an argon2id digest' do
      expect(described_class.needs_upgrade?(described_class.hash(password))).to be false
    end
  end

  describe '.bcrypt?' do
    it 'returns true for $2a$ prefix (standard bcrypt)' do
      expect(described_class.bcrypt?('$2a$12$somehashvalue')).to be true
    end

    it 'returns true for $2b$ prefix (canonical bcrypt)' do
      expect(described_class.bcrypt?('$2b$12$somehashvalue')).to be true
    end

    it 'returns false for an argon2id digest' do
      expect(described_class.bcrypt?('$argon2id$v=19$m=65536,t=3,p=2$salt$hash')).to be false
    end

    it 'returns false for a blank string' do
      expect(described_class.bcrypt?('')).to be false
    end
  end
end
