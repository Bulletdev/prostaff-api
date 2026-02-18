# frozen_string_literal: true

# TeamChannel — Real-time messaging channel for team communication.
#
# Each user subscribes to the stream of their own organization.
# The stream key is derived from `current_org_id` (set in Connection),
# so a user cannot subscribe to another organization's stream even by
# manually crafting a subscription request.
#
# Actions:
#   subscribed   → opens the org-scoped stream
#   unsubscribed → stops all streams (cleanup)
#   speak        → receives a message from the client, persists it, then
#                  broadcasts to the org stream via after_create callback
#
# Broadcasting is done by the Message model's after_create callback,
# not directly in this channel, to keep the channel thin and testable.
class TeamChannel < ApplicationCable::Channel
  # Maximum message length — enforced at channel level before hitting the DB
  MAX_CONTENT_LENGTH = 2000

  def subscribed
    if current_org_id.blank?
      logger.warn "[TeamChannel] Rejected subscription — no org_id for user #{current_user.id}"
      reject
      return
    end

    stream_name = "team_room_#{current_org_id}"
    stream_from stream_name
    logger.info "[TeamChannel] user=#{current_user.id} subscribed to #{stream_name}"
  end

  def unsubscribed
    stop_all_streams
    logger.info "[TeamChannel] user=#{current_user.id} disconnected"
  end

  # Receives a message sent by the frontend via cable.
  #
  # @param data [Hash] { "content" => "message text" }
  def speak(data)
    content = data['content'].to_s.strip

    if content.blank?
      transmit({ error: 'Message content cannot be blank' })
      return
    end

    if content.length > MAX_CONTENT_LENGTH
      transmit({ error: "Message exceeds #{MAX_CONTENT_LENGTH} characters" })
      return
    end

    # Persist the message — broadcasting is triggered by after_create callback
    Message.create!(
      content: content,
      user: current_user,
      organization_id: current_org_id
    )
  rescue ActiveRecord::RecordInvalid => e
    logger.error "[TeamChannel] Failed to create message: #{e.message}"
    transmit({ error: 'Failed to send message' })
  end
end
