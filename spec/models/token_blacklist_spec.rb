# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TokenBlacklist, type: :model do
  describe 'validations' do
    subject { build(:token_blacklist) }

    it { is_expected.to validate_presence_of(:jti) }
    it { is_expected.to validate_presence_of(:expires_at) }
    it { is_expected.to validate_uniqueness_of(:jti) }
  end

  describe '.blacklisted?' do
    context 'when the jti is in the blacklist and not expired' do
      it 'returns true' do
        described_class.create!(jti: 'valid-jti', expires_at: 1.hour.from_now)
        expect(described_class.blacklisted?('valid-jti')).to be(true)
      end
    end

    context 'when the jti is in the blacklist but expired' do
      it 'returns false' do
        described_class.create!(jti: 'expired-jti', expires_at: 1.hour.ago)
        expect(described_class.blacklisted?('expired-jti')).to be(false)
      end
    end

    context 'when the jti is unknown' do
      it 'returns false' do
        expect(described_class.blacklisted?('unknown-jti')).to be(false)
      end
    end
  end

  describe '.add_to_blacklist' do
    it 'creates a new blacklist record' do
      expect {
        described_class.add_to_blacklist('new-jti', 1.hour.from_now)
      }.to change(described_class, :count).by(1)
    end

    it 'stores the correct jti and expires_at' do
      expires = 2.hours.from_now
      described_class.add_to_blacklist('stored-jti', expires)
      record = described_class.find_by(jti: 'stored-jti')
      expect(record).to be_present
      expect(record.expires_at).to be_within(1.second).of(expires)
    end

    it 'returns nil and does not raise when jti already exists' do
      described_class.create!(jti: 'dup-jti', expires_at: 1.hour.from_now)
      expect {
        result = described_class.add_to_blacklist('dup-jti', 1.hour.from_now)
        expect(result).to be_nil
      }.not_to raise_error
    end
  end

  describe '.cleanup_expired' do
    it 'deletes expired entries' do
      described_class.create!(jti: 'expired-cleanup', expires_at: 1.minute.ago)
      described_class.create!(jti: 'active-cleanup', expires_at: 1.hour.from_now)

      expect {
        described_class.cleanup_expired
      }.to change(described_class, :count).by(-1)

      expect(described_class.find_by(jti: 'active-cleanup')).to be_present
      expect(described_class.find_by(jti: 'expired-cleanup')).to be_nil
    end
  end

  describe 'scopes' do
    before do
      described_class.create!(jti: 'scope-valid', expires_at: 1.hour.from_now)
      described_class.create!(jti: 'scope-expired', expires_at: 1.minute.ago)
    end

    describe '.valid' do
      it 'returns only non-expired entries' do
        jtis = described_class.valid.pluck(:jti)
        expect(jtis).to include('scope-valid')
        expect(jtis).not_to include('scope-expired')
      end
    end

    describe '.expired' do
      it 'returns only expired entries' do
        jtis = described_class.expired.pluck(:jti)
        expect(jtis).to include('scope-expired')
        expect(jtis).not_to include('scope-valid')
      end
    end
  end
end
