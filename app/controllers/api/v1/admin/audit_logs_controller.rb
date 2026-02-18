# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Admin controller for audit log viewing
      #
      # Provides read-only access to audit logs for compliance and security monitoring.
      # Only accessible to admin users.
      #
      class AuditLogsController < Api::V1::BaseController
        before_action :require_admin_access

        # GET /api/v1/admin/audit-logs
        # Lists all audit logs with filtering options
        def index
          scope = AuditLog.includes(:user, :organization)

          # Apply filters (note: use params[:filter_action] to avoid conflict with Rails' reserved params[:action])
          scope = scope.where(action: params[:filter_action]) if params[:filter_action].present?
          scope = scope.where(entity_type: params[:entity_type]) if params[:entity_type].present?
          scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?

          # Order by most recent first
          scope = scope.order(created_at: :desc)

          # Paginate
          result = paginate(scope)

          render_success({
                           logs: result[:data].map { |log| serialize_audit_log(log) },
                           pagination: result[:pagination]
                         })
        end

        private

        def require_admin_access
          unless current_user&.admin? || current_user&.owner?
            render_error(
              message: 'Admin access required',
              code: 'FORBIDDEN',
              status: :forbidden
            )
          end
        end

        def serialize_audit_log(log)
          {
            id: log.id,
            user: {
              id: log.user.id,
              email: log.user.email,
              full_name: log.user.full_name
            },
            organization: {
              id: log.organization.id,
              name: log.organization.name
            },
            action: log.action,
            entity_type: log.entity_type,
            entity_id: log.entity_id,
            old_values: log.old_values,
            new_values: log.new_values,
            created_at: log.created_at.iso8601
          }
        end
      end
    end
  end
end
