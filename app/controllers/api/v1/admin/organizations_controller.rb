# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Admin controller for organization management
      #
      # Provides platform-level visibility into all organizations.
      # Only accessible to admin/owner users.
      class OrganizationsController < Api::V1::BaseController
        before_action :require_admin_access

        # GET /api/v1/admin/organizations
        def index
          scope = Organization.includes(:users).order(created_at: :desc)

          scope = scope.where('LOWER(name) LIKE ?', "%#{params[:search].downcase}%") if params[:search].present?
          scope = scope.where(tier: params[:tier]) if params[:tier].present?
          scope = scope.where(subscription_status: params[:status]) if params[:status].present?

          result = paginate(scope)

          render_success({
            organizations: result[:data].map { |org| serialize_org(org) },
            pagination:    result[:pagination]
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

        def serialize_org(org)
          {
            id:                  org.id,
            name:                org.name,
            slug:                org.slug,
            region:              org.region,
            tier:                org.tier,
            subscription_plan:   org.subscription_plan,
            subscription_status: org.subscription_status,
            users_count:         org.users.size,
            created_at:          org.created_at.iso8601
          }
        end
      end
    end
  end
end
