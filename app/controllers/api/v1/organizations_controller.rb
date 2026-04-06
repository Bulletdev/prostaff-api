# frozen_string_literal: true

module Api
  module V1
    # Organizations Controller
    # Allows org admins/owners to update their own organization settings and logo
    class OrganizationsController < Api::V1::BaseController
      before_action :set_organization
      before_action :require_admin_or_owner

      # PATCH /api/v1/organizations/:id
      def update
        if @organization.update(org_params)
          render json: {
            message: 'Organization updated successfully',
            organization: OrganizationSerializer.render_as_hash(@organization)
          }, status: :ok
        else
          render_error(
            message: 'Validation failed',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: @organization.errors.as_json
          )
        end
      end

      # POST /api/v1/organizations/:id/logo
      def upload_logo
        file = params[:file]

        unless file
          return render_error(
            message: 'No file provided',
            code: 'MISSING_FILE',
            status: :unprocessable_entity
          )
        end

        service = S3UploadService.new
        result = service.upload(file, prefix: "orgs/#{@organization.id}/logo")
        logo_url = service.public_url(result[:key])

        @organization.update!(logo_url: logo_url)

        render json: {
          message: 'Logo uploaded successfully',
          logo_url: logo_url
        }, status: :ok
      rescue ArgumentError => e
        render_error(
          message: e.message,
          code: 'INVALID_FILE',
          status: :unprocessable_entity
        )
      end

      private

      def set_organization
        @organization = current_organization
        render_not_found unless @organization
      end

      def require_admin_or_owner
        allowed_roles = %w[admin owner]
        unless allowed_roles.include?(@current_user.role)
          return render_error(
            message: 'Only admins and owners can update organization settings',
            code: 'FORBIDDEN',
            status: :forbidden
          )
        end
      end

      def org_params
        params.require(:organization).permit(:name, :region, :public_tagline)
      end
    end
  end
end
