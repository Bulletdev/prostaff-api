# frozen_string_literal: true

module Manager
  module Controllers
    # CRUD operations for non-player staff members.
    #
    # Restricted to owner, admin, and manager roles.
    # Soft-delete (destroy) sets status to terminated + deleted_at without removing the record.
    #
    # @example Add a new staff member
    #   POST /api/v1/manager/staff
    #
    # @example Soft-delete a staff member
    #   DELETE /api/v1/manager/staff/:id
    class StaffMembersController < Api::V1::BaseController
      before_action :require_manager_access!
      before_action :set_staff_member, only: %i[show update destroy]
      after_action  :verify_authorized

      # GET /api/v1/manager/staff/:id
      def show
        authorize @staff_member, policy_class: Manager::StaffMemberPolicy
        render_success({ staff_member: Manager::StaffMemberSerializer.render_as_hash(@staff_member) })
      end

      # POST /api/v1/manager/staff
      def create
        authorize StaffMember, :create?, policy_class: Manager::StaffMemberPolicy
        member = organization_scoped(StaffMember).new(staff_params)
        member.save!
        log_user_action(action: 'create', entity_type: 'StaffMember', entity_id: member.id)
        render_created({ staff_member: Manager::StaffMemberSerializer.render_as_hash(member) })
      end

      # PATCH /api/v1/manager/staff/:id
      def update
        authorize @staff_member, policy_class: Manager::StaffMemberPolicy
        @staff_member.update!(staff_params)
        log_user_action(action: 'update', entity_type: 'StaffMember', entity_id: @staff_member.id)
        render_success({ staff_member: Manager::StaffMemberSerializer.render_as_hash(@staff_member) })
      end

      # DELETE /api/v1/manager/staff/:id
      # Soft-delete: sets status to terminated and deleted_at to now.
      def destroy
        authorize @staff_member, policy_class: Manager::StaffMemberPolicy
        @staff_member.soft_delete!
        log_user_action(action: 'destroy', entity_type: 'StaffMember', entity_id: @staff_member.id)
        render_deleted(message: 'Staff member removed')
      end

      private

      def require_manager_access!
        require_role!('owner', 'admin', 'manager')
      end

      def set_staff_member
        @staff_member = organization_scoped(StaffMember).not_deleted.find(params[:id])
      end

      def staff_params
        # :role is the professional staff role (head_coach, analyst, etc.),
        # not a user authorization role — no privilege escalation possible.
        # nosemgrep: ruby.lang.security.model-attr-accessible.model-attr-accessible
        params.require(:staff_member).permit(
          :name, :role, :status, :line, :country, :birth_date,
          :contract_start_date, :contract_end_date, :contract_id,
          :twitter_handle, :instagram_handle, :avatar_url, :notes
        )
      end
    end
  end
end
