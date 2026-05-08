# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JwtService do
  let(:org)  { create(:organization) }
  let(:user) { create(:user, organization: org) }

  # ---------------------------------------------------------------------------
  # .encode
  # ---------------------------------------------------------------------------

  describe '.encode' do
    it 'returns a non-blank string' do
      token = described_class.encode({ user_id: user.id })
      expect(token).to be_a(String).and be_present
    end

    it 'includes jti in the payload' do
      token = described_class.encode({ user_id: user.id })
      payload = described_class.decode(token)
      expect(payload[:jti]).to be_present
    end

    it 'includes exp in the payload' do
      token = described_class.encode({ user_id: user.id })
      payload = described_class.decode(token)
      expect(payload[:exp]).to be_a(Integer)
    end

    it 'respects custom_expiration' do
      future = 2.hours.from_now.to_i
      token = described_class.encode({ user_id: user.id }, custom_expiration: future)
      payload = described_class.decode(token)
      expect(payload[:exp]).to eq(future)
    end
  end

  # ---------------------------------------------------------------------------
  # .decode
  # ---------------------------------------------------------------------------

  describe '.decode' do
    it 'returns a HashWithIndifferentAccess with the original payload' do
      token   = described_class.encode({ user_id: user.id, role: 'admin' })
      payload = described_class.decode(token)
      expect(payload[:user_id]).to eq(user.id)
      expect(payload[:role]).to eq('admin')
    end

    it 'raises TokenExpiredError for an expired token' do
      token = described_class.encode(
        { user_id: user.id },
        custom_expiration: 1.hour.ago.to_i
      )
      expect { described_class.decode(token) }.to raise_error(JwtService::TokenExpiredError)
    end

    it 'raises TokenInvalidError for a malformed token' do
      expect { described_class.decode('not.a.valid.jwt') }.to raise_error(JwtService::TokenInvalidError)
    end

    it 'raises TokenRevokedError for a blacklisted token' do
      token = described_class.encode({ user_id: user.id })
      described_class.blacklist_token(token)
      expect { described_class.decode(token) }.to raise_error(JwtService::TokenRevokedError)
    end
  end

  # ---------------------------------------------------------------------------
  # .generate_tokens
  # ---------------------------------------------------------------------------

  describe '.generate_tokens' do
    subject(:tokens) { described_class.generate_tokens(user) }

    it 'returns access_token and refresh_token' do
      expect(tokens[:access_token]).to be_present
      expect(tokens[:refresh_token]).to be_present
    end

    it 'returns expires_in as a positive integer' do
      expect(tokens[:expires_in]).to be_a(Integer).and be_positive
    end

    it 'encodes type=access in access_token' do
      payload = described_class.decode(tokens[:access_token])
      expect(payload[:type]).to eq('access')
    end

    it 'encodes type=refresh in refresh_token' do
      payload = described_class.decode(tokens[:refresh_token])
      expect(payload[:type]).to eq('refresh')
    end

    it 'encodes user_id in access_token' do
      payload = described_class.decode(tokens[:access_token])
      expect(payload[:user_id]).to eq(user.id)
    end
  end

  # ---------------------------------------------------------------------------
  # .generate_player_tokens
  # ---------------------------------------------------------------------------

  describe '.generate_player_tokens' do
    let(:player) { create(:player, organization: org) }
    subject(:tokens) { described_class.generate_player_tokens(player) }

    it 'returns access_token and refresh_token' do
      expect(tokens[:access_token]).to be_present
      expect(tokens[:refresh_token]).to be_present
    end

    it 'encodes entity_type=player in the access token' do
      payload = described_class.decode(tokens[:access_token])
      expect(payload[:entity_type]).to eq('player')
    end

    it 'encodes the player_id' do
      payload = described_class.decode(tokens[:access_token])
      expect(payload[:player_id]).to eq(player.id)
    end
  end

  # ---------------------------------------------------------------------------
  # .refresh_access_token
  # ---------------------------------------------------------------------------

  describe '.refresh_access_token' do
    let(:tokens) { described_class.generate_tokens(user) }

    it 'returns new tokens when given a valid refresh token' do
      new_tokens = described_class.refresh_access_token(tokens[:refresh_token])
      expect(new_tokens[:access_token]).to be_present
      expect(new_tokens[:refresh_token]).to be_present
    end

    it 'blacklists the old refresh token after rotation' do
      old_refresh = tokens[:refresh_token]
      described_class.refresh_access_token(old_refresh)
      expect { described_class.decode(old_refresh) }.to raise_error(JwtService::TokenRevokedError)
    end

    it 'raises TokenInvalidError when given an access token instead' do
      expect do
        described_class.refresh_access_token(tokens[:access_token])
      end.to raise_error(JwtService::TokenInvalidError)
    end

    it 'raises TokenExpiredError for expired refresh token' do
      expired = described_class.encode(
        { user_id: user.id, type: 'refresh' },
        custom_expiration: 1.hour.ago.to_i
      )
      expect { described_class.refresh_access_token(expired) }.to raise_error(JwtService::TokenExpiredError)
    end

    it 'raises UserNotFoundError when user no longer exists' do
      refresh = described_class.encode({ user_id: SecureRandom.uuid, type: 'refresh' })
      expect { described_class.refresh_access_token(refresh) }.to raise_error(JwtService::UserNotFoundError)
    end
  end

  # ---------------------------------------------------------------------------
  # .blacklist_token
  # ---------------------------------------------------------------------------

  describe '.blacklist_token' do
    it 'adds the jti to TokenBlacklist' do
      token = described_class.encode({ user_id: user.id })
      expect { described_class.blacklist_token(token) }
        .to change { TokenBlacklist.count }.by(1)
    end

    it 'does not raise for a malformed token (graceful failure)' do
      expect { described_class.blacklist_token('garbage') }.not_to raise_error
    end
  end
end
