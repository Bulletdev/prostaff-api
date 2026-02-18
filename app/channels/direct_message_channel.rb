# frozen_string_literal: true

# DirectMessageChannel — real-time private messaging between two team members.
#
# The frontend subscribes passing the recipient_id:
#   consumer.subscriptions.create(
#     { channel: 'DirectMessageChannel', recipient_id: '<uuid>' },
#     { received(data) { ... } }
#   )
#
# Security guarantees:
#   1. Sender identity comes from the verified JWT (current_user) — cannot be spoofed.
#   2. Recipient must belong to the same organization as the sender.
#   3. Stream key is derived from sorted user IDs + org_id — impossible to subscribe
#      to a conversation you're not a party to.
class DirectMessageChannel < ApplicationCable::Channel
  MAX_CONTENT_LENGTH = 2000

  def subscribed
    recipient = find_and_validate_recipient
    return unless recipient

    @recipient_id = recipient.id
    stream_from stream_key_for(recipient)
    logger.info "[DM] #{current_user.id} subscribed to DM with #{recipient.id}"
  end

  def unsubscribed
    stop_all_streams
  end

  # Receives { "content" => "...", "recipient_id" => "..." } from the frontend.
  def speak(data)
    content      = data['content'].to_s.strip
    recipient_id = data['recipient_id'].to_s

    if content.blank?
      transmit({ error: 'Message content cannot be blank' })
      return
    end

    if content.length > MAX_CONTENT_LENGTH
      transmit({ error: "Message exceeds #{MAX_CONTENT_LENGTH} characters" })
      return
    end

    recipient = find_recipient_by_id(recipient_id)
    return unless recipient

    Message.create!(
      content:         content,
      user:            current_user,
      recipient:       recipient,
      organization_id: current_org_id
    )
  rescue ActiveRecord::RecordInvalid => e
    logger.error "[DM] Failed to create message: #{e.message}"
    transmit({ error: 'Failed to send message' })
  end

  private

  def find_and_validate_recipient
    recipient_id = params[:recipient_id].to_s

    if recipient_id.blank?
      logger.warn "[DM] Rejected subscription — no recipient_id provided"
      reject
      return nil
    end

    find_recipient_by_id(recipient_id)
  end

  def find_recipient_by_id(recipient_id)
    recipient = User.find_by(id: recipient_id, organization_id: current_org_id)

    unless recipient
      logger.warn "[DM] Recipient #{recipient_id} not found in org #{current_org_id}"
      reject
      return nil
    end

    if recipient.id == current_user.id
      logger.warn "[DM] Cannot DM yourself"
      reject
      return nil
    end

    recipient
  end

  def stream_key_for(recipient)
    Message.dm_stream_key(current_user.id, recipient.id, current_org_id)
  end
end
