# frozen_string_literal: true

module Support
  module Controllers
    # Handles file uploads for support ticket attachments
    class UploadsController < Api::V1::BaseController
      # POST /api/v1/support/uploads
      def create
        file = params[:file]

        return render_error(message: 'No file provided', status: :unprocessable_entity) unless file

        service = S3UploadService.new
        attachment = service.upload(file, prefix: "support/#{current_user.id}")

        render_success({ attachment: attachment })
      rescue ArgumentError => e
        render_error(message: e.message, status: :unprocessable_entity)
      rescue Aws::S3::Errors::ServiceError => e
        Rails.logger.error("[Uploads] S3 error: #{e.message}")
        render_error(message: 'Upload failed. Please try again.', status: :internal_server_error)
      rescue KeyError => e
        Rails.logger.error("[Uploads] Missing env var: #{e.message}")
        render_error(message: 'Storage not configured', status: :internal_server_error)
      end
    end
  end
end
