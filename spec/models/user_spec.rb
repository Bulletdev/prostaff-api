# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  subject { build(:user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:full_name) }
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_inclusion_of(:role).in_array(Constants::User::ROLES) }

    # validate_uniqueness_of requires a persisted record with password_digest.
    # build(:user) has no password_digest until saved, causing a DB NOT NULL
    # violation. Test uniqueness manually with a created record.
    it 'validates uniqueness of email (case-insensitive)' do
      existing = create(:user)
      duplicate = build(:user, email: existing.email.upcase)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to be_present
    end

    it 'rejects invalid email format' do
      user = build(:user, email: 'not-an-email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it 'accepts valid email format' do
      user = build(:user, email: 'valid@example.com')
      expect(user).to be_valid
    end

    it 'requires password to contain uppercase letter' do
      # User has no password_confirmation attr - pass only password
      user = build(:user, password: 'alllowercase1')
      expect(user).not_to be_valid
    end

    it 'accepts a strong password' do
      user = build(:user, password: 'StrongPass1!')
      expect(user).to be_valid
    end

    it 'requires minimum password length of 8' do
      user = build(:user, password: 'Ab1')
      expect(user).not_to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_many(:notifications).dependent(:destroy) }
    it { is_expected.to have_many(:audit_logs).dependent(:destroy) }
    it { is_expected.to have_many(:password_reset_tokens).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:organization) { create(:organization) }
    let!(:active_user)  { create(:user, organization: organization, last_login_at: 1.hour.ago) }
    let!(:never_logged) { create(:user, organization: organization, last_login_at: nil) }

    describe '.by_role' do
      it 'filters users by role' do
        owner = create(:user, :owner, organization: organization)
        expect(User.by_role('owner')).to include(owner)
        expect(User.by_role('owner')).not_to include(active_user)
      end
    end

    describe '.active' do
      it 'includes users who have logged in' do
        expect(User.active).to include(active_user)
      end

      it 'excludes users who never logged in' do
        expect(User.active).not_to include(never_logged)
      end
    end
  end

  describe 'callbacks' do
    it 'downcases email before save' do
      user = create(:user, email: 'UPPER@EXAMPLE.COM')
      expect(user.reload.email).to eq('upper@example.com')
    end
  end

  describe '#admin?' do
    it 'returns true for admin role' do
      expect(build(:user, :admin).admin?).to be(true)
    end

    it 'returns false for coach role' do
      expect(build(:user, :coach).admin?).to be(false)
    end
  end

  describe '#owner?' do
    it 'returns true for owner role' do
      expect(build(:user, :owner).owner?).to be(true)
    end

    it 'returns false for admin role' do
      expect(build(:user, :admin).owner?).to be(false)
    end
  end

  describe '#admin_or_owner?' do
    it 'returns true for admin role' do
      expect(build(:user, :admin).admin_or_owner?).to be(true)
    end

    it 'returns true for owner role' do
      expect(build(:user, :owner).admin_or_owner?).to be(true)
    end

    it 'returns false for coach role' do
      expect(build(:user, :coach).admin_or_owner?).to be(false)
    end

    it 'returns false for analyst role' do
      expect(build(:user, :analyst).admin_or_owner?).to be(false)
    end
  end

  describe '#can_manage_players?' do
    it 'returns true for owner, admin, and coach' do
      %w[owner admin coach].each do |role|
        expect(build(:user, role: role).can_manage_players?).to be(true),
          "expected #{role} to manage players"
      end
    end

    it 'returns false for analyst and viewer' do
      %w[analyst viewer].each do |role|
        expect(build(:user, role: role).can_manage_players?).to be(false),
          "expected #{role} not to manage players"
      end
    end
  end

  describe '#can_view_analytics?' do
    it 'returns true for owner, admin, coach, and analyst' do
      %w[owner admin coach analyst].each do |role|
        expect(build(:user, role: role).can_view_analytics?).to be(true)
      end
    end

    it 'returns false for viewer' do
      expect(build(:user, :viewer).can_view_analytics?).to be(false)
    end
  end

  describe '#update_last_login!' do
    it 'sets last_login_at to the current time' do
      user = create(:user)
      expect { user.update_last_login! }.to change { user.reload.last_login_at }.from(nil)
    end
  end
end
