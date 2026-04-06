# frozen_string_literal: true

module Scrims
  module Controllers
    # ScrimMessagesController — REST endpoints for scrim chat history.
    #
    # Provides paginated access to the message history of a scrim and allows
    # authors to soft-delete their own messages.
    #
    # Both organizations participating in the scrim have read/delete access.
    # Authorization verifies that the current user belongs to one of the two
    # participating organizations before serving any data.
    #
    # @example Fetch history
    #   GET /api/v1/scrims/scrims/:scrim_id/messages
    #
    # @example Delete a message
    #   DELETE /api/v1/scrims/scrims/:scrim_id/messages/:id
    class ScrimMessagesController < Api::V1::BaseController
      before_action :set_authorized_scrim
      before_action :set_message, only: [:destroy]

      # GET /api/v1/scrims/scrims/:scrim_id/messages
      #
      # Returns paginated chronological history of non-deleted messages.
      #
      # @return [JSON] paginated list of scrim messages
      def index
        scrim_ids = linked_scrim_ids
        messages  = ScrimMessage.unscoped
                                .where(scrim_id: scrim_ids, deleted: false)
                                .order(created_at: :asc)
        result    = paginate(messages, per_page: 50)

        render_success({
                         messages: serialize_messages(result[:data]),
                         pagination: result[:pagination]
                       })
      end

      # DELETE /api/v1/scrims/scrims/:scrim_id/messages/:id
      #
      # Soft-deletes the message. Only the original author may delete.
      #
      # @return [JSON] deletion confirmation
      def destroy
        unless @message.user_id == current_user.id
          return render_error(
            message: 'You can only delete your own messages',
            code: 'FORBIDDEN',
            status: :forbidden
          )
        end

        @message.soft_delete!
        render_deleted(message: 'Message deleted successfully')
      end

      private

      # Finds the scrim and verifies the current user's org is a participant.
      #
      # Checks ownership org first. Falls back to ScrimRequest participant check for
      # cross-org scrims. Always returns NOT_FOUND for unauthorized access — never
      # FORBIDDEN — so that foreign scrim UUIDs are not leaked via oracle behavior.
      def set_authorized_scrim
        scrim = current_organization.scrims.find_by(id: params[:scrim_id]) ||
                cross_org_scrim(params[:scrim_id])

        return render_error(message: 'Scrim not found', code: 'NOT_FOUND', status: :not_found) unless scrim

        @scrim = scrim
      end

      # Finds a scrim via ScrimRequest where the current org is the opposing participant.
      # Returns nil when the scrim does not exist or the org is not a participant.
      def cross_org_scrim(scrim_id)
        scrim = Scrim.find_by(id: scrim_id)
        return nil unless scrim

        request = scrim_request_for(scrim)
        return nil unless request

        org_id = current_user.organization_id
        return scrim if request.requesting_organization_id == org_id ||
                        request.target_organization_id == org_id

        nil
      end

      def set_message
        @message = @scrim.scrim_messages.active.find_by(id: params[:id])

        return if @message

        render_error(message: 'Message not found', code: 'NOT_FOUND', status: :not_found)
      end

      def scrim_request_for(scrim)
        return nil unless scrim.scrim_request_id.present?

        ScrimRequest.find_by(id: scrim.scrim_request_id)
      end

      # Returns IDs of all scrims sharing the same ScrimRequest (both orgs).
      # Falls back to only the current scrim when no request is linked.
      def linked_scrim_ids
        request = scrim_request_for(@scrim)
        return [@scrim.id] unless request

        [request.requesting_scrim_id, request.target_scrim_id].compact
      end

      def serialize_messages(messages)
        messages.map do |msg|
          {
            id: msg.id,
            content: msg.content,
            created_at: msg.created_at.iso8601,
            user: { id: msg.user_id, full_name: msg.user.full_name },
            organization: { id: msg.organization_id, name: msg.organization.name }
          }
        end
      end
    end
  end
end
