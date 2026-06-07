# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSerializer do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }

  subject(:result) { described_class.render_as_hash(user) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(user.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :email, :full_name, :role, :timezone, :language,
      :notifications_enabled, :created_at, :updated_at
    )
  end

  it 'does not expose password_digest' do
    expect(result.keys).not_to include(:password_digest)
  end

  it 'does not expose jti' do
    expect(result.keys).not_to include(:jti)
  end

  it 'does not expose encrypted_password' do
    expect(result.keys).not_to include(:encrypted_password)
  end

  it 'exposes email as a string' do
    expect(result[:email]).to be_a(String)
    expect(result[:email]).to include('@')
  end

  it 'exposes role as a string' do
    expect(result[:role]).to be_a(String)
  end

  describe 'role_display field' do
    it 'is a string' do
      expect(result[:role_display]).to be_a(String)
    end
  end

  describe 'permissions field' do
    it 'includes all permission keys' do
      expect(result[:permissions]).to include(
        :can_manage_users,
        :can_manage_players,
        :can_view_analytics,
        :is_admin_or_owner
      )
    end

    it 'has boolean values' do
      result[:permissions].each_value do |val|
        expect(val).to be_in([true, false])
      end
    end

    context 'when user is admin' do
      it 'grants admin-level permissions' do
        expect(result[:permissions][:is_admin_or_owner]).to be(true)
      end
    end

    context 'when user is viewer' do
      let(:user) { create(:user, :viewer, organization: organization) }

      it 'restricts admin permissions' do
        expect(result[:permissions][:is_admin_or_owner]).to be(false)
      end
    end
  end

  describe 'last_login_display field' do
    context 'when user has never logged in' do
      let(:user) { create(:user, organization: organization, last_login_at: nil) }

      it 'returns Never' do
        expect(result[:last_login_display]).to eq('Never')
      end
    end

    context 'when user logged in recently' do
      let(:user) { create(:user, organization: organization, last_login_at: 5.minutes.ago) }

      it 'returns a time-ago string' do
        expect(result[:last_login_display]).to be_a(String)
        expect(result[:last_login_display]).not_to eq('Never')
      end
    end
  end
end
