# frozen_string_literal: true

module Core
  module Controllers
    # TeamMembersController — lists all messageable members in the same organization.
    #
    # Returns staff users and players with player access enabled, used by
    # the frontend to populate the DM recipient list in the chat widget.
    # Player tokens are rejected — this endpoint requires a user token.
    #
    # GET /api/v1/team-members
    class TeamMembersController < Api::V1::BaseController
      before_action :require_user_auth!

      def index
        users = current_organization
                .users
                .where.not(id: current_user.id)
                .order(:full_name)
                .select(:id, :full_name, :role, :last_login_at, :avatar_url)
                .map { |u| serialize_member(u) }

        players = current_organization
                  .players
                  .where(player_access_enabled: true)
                  .order(:professional_name, :real_name)
                  .select(:id, :professional_name, :real_name, :role, :last_login_at, :avatar_url)
                  .map { |p| serialize_player(p) }

        render_success({ members: users + players })
      end

      private

      def serialize_member(user)
        {
          id: user.id,
          full_name: user.full_name,
          role: user.role,
          online: active_recently?(user.last_login_at),
          member_type: 'user',
          avatar_url: user.avatar_url.presence
        }
      end

      def serialize_player(player)
        {
          id: player.id,
          full_name: player.professional_name.presence || player.real_name || 'Player',
          role: player.role || 'player',
          online: active_recently?(player.last_login_at),
          member_type: 'player',
          avatar_url: player.avatar_url.presence
        }
      end

      def active_recently?(last_login_at)
        last_login_at.present? && last_login_at > 15.minutes.ago
      end
    end
  end
end
