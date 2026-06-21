# frozen_string_literal: true

module Manager
  module Controllers
    # Provides a unified view of all organization members for the Manager Hub.
    #
    # Returns active players and all non-deleted staff members in separate groups.
    # Coaches and managers may view; only managers may mutate via StaffMembersController.
    #
    # @example Fetch all org members
    #   GET /api/v1/manager/people
    class PeopleController < Api::V1::BaseController
      before_action :require_coach_or_manager!
      after_action  :verify_authorized

      # GET /api/v1/manager/people
      def index
        authorize StaffMember, :index?, policy_class: Manager::StaffMemberPolicy
        render_success({
                         players: serialized_players,
                         staff: serialized_staff,
                         totals: build_totals
                       })
      end

      private

      def require_coach_or_manager!
        require_role!('owner', 'admin', 'manager', 'coach')
      end

      def active_players
        @active_players ||= organization_scoped(Player)
                            .where(status: 'active')
                            .includes(:active_contract)
                            .order(:role, :professional_name)
      end

      def active_staff
        @active_staff ||= organization_scoped(StaffMember)
                          .not_deleted
                          .includes(:contract)
                          .order(:role, :name)
      end

      def serialized_players
        PlayerSummarySerializer.render_as_hash(active_players)
      end

      def serialized_staff
        Manager::StaffMemberSerializer.render_as_hash(active_staff)
      end

      def build_totals
        {
          players: active_players.size,
          staff: active_staff.size,
          total: active_players.size + active_staff.size
        }
      end
    end
  end
end
