# frozen_string_literal: true

# DirectMessageChannel — real-time private messaging between staff and players.
#
# The frontend subscribes passing recipient_id and optionally recipient_type:
#   consumer.subscriptions.create(
#     { channel: 'DirectMessageChannel', recipient_id: '<uuid>', recipient_type: 'Player' },
#     { received(data) { ... } }
#   )
#
# Security guarantees:
#   1. Sender identity comes from the verified JWT (current_user or current_player) — cannot be spoofed.
#   2. Recipient must belong to the same organization as the sender.
#   3. Stream key is derived from sorted participant IDs + org_id — impossible to subscribe
#      to a conversation you are not a party to.
class DirectMessageChannel < ApplicationCable::Channel
  MAX_CONTENT_LENGTH = 2000

  def subscribed
    recipient = find_and_validate_recipient
    return unless recipient

    @recipient_id   = recipient[:record].id
    @recipient_type = recipient[:type]
    stream_from Message.dm_stream_key(current_sender_id, @recipient_id, current_org_id)
    logger.info "[DM] #{current_sender_id} subscribed to DM with #{@recipient_id}"
  end

  def unsubscribed
    stop_all_streams
  end

  # Receives { "content" => "...", "recipient_id" => "...", "recipient_type" => "..." } from client.
  def speak(data) # rubocop:disable Metrics/MethodLength
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

    create_message(content: content, recipient: recipient)
  rescue ActiveRecord::RecordInvalid => e
    logger.error "[DM] Failed to create message: #{e.message}"
    transmit({ error: 'Failed to send message' })
  end

  private

  def find_and_validate_recipient
    recipient_id = params[:recipient_id].to_s

    if recipient_id.blank?
      logger.warn '[DM] Rejected subscription — no recipient_id provided'
      reject
      return nil
    end

    find_recipient_by_id(recipient_id)
  end

  def find_recipient_by_id(recipient_id)
    recipient_type = resolve_recipient_type(params[:recipient_type])
    record = locate_recipient(recipient_id, recipient_type)

    unless record
      logger.warn "[DM] Recipient #{recipient_id} (#{recipient_type}) not found in org #{current_org_id}"
      reject
      return nil
    end

    if record.id == current_sender_id
      logger.warn '[DM] Cannot DM yourself'
      reject
      return nil
    end

    { record: record, type: recipient_type }
  end

  def locate_recipient(recipient_id, recipient_type)
    if recipient_type == 'Player'
      Player.find_by(id: recipient_id, organization_id: current_org_id, player_access_enabled: true)
    else
      User.find_by(id: recipient_id, organization_id: current_org_id)
    end
  end

  def resolve_recipient_type(raw_type)
    Message::PARTICIPANT_TYPES.include?(raw_type.to_s) ? raw_type.to_s : 'User'
  end

  def create_message(content:, recipient:)
    Message.create!(
      user_id: current_sender_id,
      sender_type: current_sender_type,
      recipient_id: recipient[:record].id,
      recipient_type: recipient[:type],
      organization_id: current_org_id,
      content: content
    )
  end

  def current_sender_id
    return current_player.id if current_player.present?

    current_user.id
  end

  def current_sender_type
    current_player.present? ? 'Player' : 'User'
  end
end
