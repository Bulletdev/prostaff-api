# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }

  def user_token(u = user)
    JwtService.generate_tokens(u)[:access_token]
  end

  def player_token(p)
    JwtService.generate_player_tokens(p)[:access_token]
  end

  describe 'connect' do
    context 'with a valid user JWT' do
      it 'accepts the connection and sets current_user' do
        connect '/cable', params: { token: user_token }

        expect(connection.current_user).to eq(user)
        expect(connection.current_player).to be_nil
        expect(connection.current_org_id).to eq(organization.id)
      end
    end

    context 'with a valid player JWT' do
      let(:player) { create(:player, organization: organization, player_access_enabled: true) }

      it 'accepts the connection and sets current_player' do
        connect '/cable', params: { token: player_token(player) }

        expect(connection.current_player).to eq(player)
        expect(connection.current_user).to be_nil
        expect(connection.current_org_id).to eq(organization.id)
      end
    end

    context 'when no token is provided' do
      it 'rejects the connection' do
        expect { connect '/cable' }.to have_rejected_connection
      end
    end

    context 'when token is blank string' do
      it 'rejects the connection' do
        expect { connect '/cable', params: { token: '' } }.to have_rejected_connection
      end
    end

    context 'when token is malformed (not a valid JWT)' do
      it 'rejects the connection' do
        expect { connect '/cable', params: { token: 'not.a.jwt' } }.to have_rejected_connection
      end
    end

    context 'when token is a refresh token (not an access token)' do
      it 'rejects the connection' do
        refresh_token = JwtService.generate_tokens(user)[:refresh_token]
        expect { connect '/cable', params: { token: refresh_token } }.to have_rejected_connection
      end
    end

    context 'when token is expired' do
      it 'rejects the connection' do
        expired_token = JwtService.encode(
          { user_id: user.id, organization_id: organization.id, type: 'access' },
          custom_expiration: 1.hour.ago.to_i
        )
        expect { connect '/cable', params: { token: expired_token } }.to have_rejected_connection
      end
    end

    context 'when user_id in token does not exist' do
      it 'rejects the connection' do
        token = JwtService.encode(
          { user_id: SecureRandom.uuid, organization_id: organization.id, type: 'access' }
        )
        expect { connect '/cable', params: { token: token } }.to have_rejected_connection
      end
    end

    context 'when player access is disabled' do
      let(:player) { create(:player, organization: organization, player_access_enabled: false) }

      it 'rejects the connection' do
        token = JwtService.encode(
          { entity_type: 'player', player_id: player.id, organization_id: organization.id, type: 'access' }
        )
        expect { connect '/cable', params: { token: token } }.to have_rejected_connection
      end
    end

    context 'when user has no organization (stubbed)' do
      it 'rejects the connection' do
        # The DB enforces NOT NULL on organization_id, so we stub the model to
        # simulate a user with a blank org_id without hitting the constraint.
        user_stub = instance_double(User, id: user.id, organization_id: nil)
        allow(User).to receive(:find_by).with(id: user.id).and_return(user_stub)

        token = JwtService.encode(
          { user_id: user.id, organization_id: nil, type: 'access' }
        )

        expect { connect '/cable', params: { token: token } }.to have_rejected_connection
      end
    end
  end
end
