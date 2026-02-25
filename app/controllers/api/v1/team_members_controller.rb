# frozen_string_literal: true

module Api
  module V1
    # TeamMembersController — lists users in the same organization.
    #
    # Used by the frontend to populate the team member list in the chat widget.
    # Returns all users except the current user.
    # Player tokens are rejected — this endpoint is for staff only.
    #
    # GET /api/v1/team-members
    class TeamMembersController < BaseController
      before_action :require_user_auth!

      def index
        members = current_organization
          .users
          .where.not(id: current_user.id)
          .order(:full_name)
          .select(:id, :full_name, :role, :last_login_at)

        render_success(
          members: members.map { |u| serialize_member(u) }
        )
      end

      private

      def serialize_member(user)
        {
          id:           user.id,
          full_name:    user.full_name,
          role:         user.role,
          online:       user.last_login_at.present? && user.last_login_at > 15.minutes.ago
        }
      end
    end
  end
end
