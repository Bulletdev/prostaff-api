# frozen_string_literal: true

module Api
  module V1
    # MessagesController — REST endpoint for DM conversation history.
    #
    # GET  /api/v1/messages?recipient_id=<uuid>  → conversation history (paginated)
    # DELETE /api/v1/messages/:id                → soft-delete own message
    class MessagesController < BaseController
      before_action :set_message, only: [:destroy]

      # GET /api/v1/messages?recipient_id=<uuid>
      # Returns the conversation history between current_user and recipient,
      # paginated newest-first (use `before` param as cursor for "load more").
      def index
        recipient_id = params.require(:recipient_id)
        recipient    = find_org_member!(recipient_id)
        return unless recipient

        messages = current_organization
          .messages
          .active
          .conversation_between(current_user.id, recipient.id)
          .includes(:user)
          .recent_first

        if params[:before].present?
          before_time = Time.parse(params[:before])
          messages = messages.where('created_at < ?', before_time)
        end

        result = paginate(messages, per_page: 50)

        render_success(
          messages:   serialize_messages(result[:data].reverse),
          pagination: result[:pagination]
        )
      rescue ActionController::ParameterMissing
        render_error(
          message: 'recipient_id is required',
          code:    'PARAMETER_MISSING',
          status:  :bad_request
        )
      rescue ArgumentError
        render_error(
          message: 'Invalid datetime format for "before" parameter',
          code:    'INVALID_PARAMETER',
          status:  :bad_request
        )
      end

      # DELETE /api/v1/messages/:id
      def destroy
        unless can_delete?(@message)
          return render_error(
            message: 'You can only delete your own messages',
            code:    'FORBIDDEN',
            status:  :forbidden
          )
        end

        @message.soft_delete!
        render_deleted(message: 'Message deleted')
      end

      private

      def set_message
        @message = current_organization.messages.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def find_org_member!(user_id)
        member = current_organization.users.find_by(id: user_id)
        unless member
          render_error(
            message: 'Recipient not found in your organization',
            code:    'NOT_FOUND',
            status:  :not_found
          )
          return nil
        end
        member
      end

      def can_delete?(message)
        message.user_id == current_user.id || current_user.admin_or_owner?
      end

      def serialize_messages(messages)
        messages.map do |msg|
          {
            id:           msg.id,
            content:      msg.content,
            created_at:   msg.created_at.iso8601,
            recipient_id: msg.recipient_id,
            user: {
              id:        msg.user.id,
              full_name: msg.user.full_name,
              role:      msg.user.role
            }
          }
        end
      end
    end
  end
end
