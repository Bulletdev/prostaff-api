# frozen_string_literal: true

module Messaging
  module Controllers
    # MessagesController — REST endpoint for DM conversation history.
    #
    # GET  /api/v1/messages?recipient_id=<uuid>  → conversation history (paginated)
    # DELETE /api/v1/messages/:id                → soft-delete own message
    #
    # Supports both staff (User token) and player (Player token) senders.
    # Recipients can be Users or Players with player_access_enabled.
    class MessagesController < Api::V1::BaseController
      before_action :set_message, only: [:destroy]

      # GET /api/v1/messages?recipient_id=<uuid>
      # Returns the conversation history between the current sender and recipient,
      # paginated newest-first (use `before` param as cursor for "load more").
      def index
        recipient_id = params.require(:recipient_id)
        recipient_info = find_org_member!(recipient_id)
        return unless recipient_info

        messages = fetch_conversation(recipient_info[:record].id)
        result = paginate(messages, per_page: 50)

        render_success({
                         messages: serialize_messages(result[:data].reverse),
                         pagination: result[:pagination]
                       })
      rescue ActionController::ParameterMissing
        render_error(
          message: 'recipient_id is required',
          code: 'PARAMETER_MISSING',
          status: :bad_request
        )
      rescue ArgumentError
        render_error(
          message: 'Invalid datetime format for "before" parameter',
          code: 'INVALID_PARAMETER',
          status: :bad_request
        )
      end

      # DELETE /api/v1/messages/:id
      def destroy
        unless can_delete?(@message)
          return render_error(
            message: 'You can only delete your own messages',
            code: 'FORBIDDEN',
            status: :forbidden
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

      def find_org_member!(recipient_id)
        user = current_organization.users.find_by(id: recipient_id)
        return { record: user, type: 'User' } if user

        player = current_organization.players.find_by(id: recipient_id, player_access_enabled: true)
        return { record: player, type: 'Player' } if player

        render_error(message: 'Recipient not found', code: 'NOT_FOUND', status: :not_found)
        nil
      end

      def fetch_conversation(recipient_id)
        sender_id = current_sender_id
        messages = current_organization
                   .messages
                   .active
                   .conversation_between(sender_id, recipient_id)
                   .recent_first

        return messages unless params[:before].present?

        before_time = Time.parse(params[:before])
        messages.where('created_at < ?', before_time)
      end

      def current_sender_id
        return current_player.id if player_authenticated?

        current_user.id
      end

      def can_delete?(message)
        return message.user_id == current_player.id if player_authenticated?

        message.user_id == current_user.id || current_user.admin_or_owner?
      end

      def serialize_messages(messages)
        sender_cache = build_sender_cache(messages)
        messages.map { |msg| serialize_message(msg, sender_cache) }
      end

      def build_sender_cache(messages)
        user_ids   = messages.select { |m| m.sender_type == 'User' }.map(&:user_id).uniq
        player_ids = messages.select { |m| m.sender_type == 'Player' }.map(&:user_id).uniq

        users   = user_ids.any? ? User.where(id: user_ids).index_by(&:id) : {}
        players = player_ids.any? ? Player.where(id: player_ids).index_by(&:id) : {}

        { 'User' => users, 'Player' => players }
      end

      def serialize_message(msg, sender_cache)
        sender = sender_cache.dig(msg.sender_type, msg.user_id)
        {
          id: msg.id,
          content: msg.content,
          created_at: msg.created_at.iso8601,
          recipient_id: msg.recipient_id,
          recipient_type: msg.recipient_type,
          sender_type: msg.sender_type,
          sender: serialize_sender(sender, msg.sender_type)
        }
      end

      def serialize_sender(sender, sender_type)
        return {} unless sender

        if sender_type == 'Player'
          { id: sender.id, full_name: sender.professional_name.presence || sender.real_name, role: sender.role }
        else
          { id: sender.id, full_name: sender.full_name, role: sender.role }
        end
      end
    end
  end
end
