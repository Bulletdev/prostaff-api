# frozen_string_literal: true

# ScrimChatChannel — Real-time cross-organization chat for scrim sessions.
#
# Allows members of both participating organizations to exchange messages
# during a scrim. Authorization is based on the scrim's owner org and its
# linked ScrimRequest, which carries both organization IDs.
#
# Subscription params:
#   scrim_id [String] — UUID of the scrim to subscribe to
#
# Actions:
#   subscribed   — validates access, opens the scrim-scoped stream
#   speak        — persists a message; broadcast is handled by the model callback
#   unsubscribed — stops all streams (cleanup)
#
# @example Frontend subscription
#   consumer.subscriptions.create(
#     { channel: 'ScrimChatChannel', scrim_id: 'uuid' },
#     { received: (data) => console.log(data) }
#   )
class ScrimChatChannel < ApplicationCable::Channel
  MAX_CONTENT_LENGTH = 1000

  def subscribed
    scrim = find_authorized_scrim
    unless scrim
      logger.warn "[ScrimChat] Rejected subscription — user=#{current_user.id} scrim_id=#{params[:scrim_id]}"
      reject
      return
    end

    @scrim = scrim
    stream_name = canonical_stream_name(@scrim)
    stream_from stream_name
    logger.info "[ScrimChat] subscribed user=#{current_user.id} scrim=#{@scrim.id} stream=#{stream_name}"
  end

  def unsubscribed
    stop_all_streams
    logger.info "[ScrimChat] user=#{current_user.id} unsubscribed"
  end

  # Receives a message from the client and persists it.
  # Broadcasting is triggered by ScrimMessage's after_create_commit callback.
  #
  # @param data [Hash] { "content" => "message text" }
  def speak(data)
    return unless @scrim

    content = validate_content(data['content'])
    return unless content

    ScrimMessage.create!(scrim: @scrim, user: current_user,
                         organization: current_user.organization, content: content)
  rescue ActiveRecord::RecordInvalid => e
    logger.error "[ScrimChat] Failed to persist message for scrim=#{@scrim.id}: #{e.message}"
    transmit({ error: 'Failed to send message' })
  end

  private

  def validate_content(raw)
    content = raw.to_s.strip
    if content.blank?
      transmit({ error: 'Message content cannot be blank' })
      return nil
    end
    if content.length > MAX_CONTENT_LENGTH
      transmit({ error: "Message exceeds #{MAX_CONTENT_LENGTH} characters" })
      return nil
    end
    content
  end

  # Finds the scrim and verifies the current user's org is a participant.
  #
  # Checks owner org first, then falls back to ScrimRequest cross-org check.
  # Always returns nil for both "not found" and "not a participant" cases so
  # that foreign scrim UUIDs are not leaked via subscription rejection messages.
  #
  # @return [Scrim, nil]
  def find_authorized_scrim
    scrim_id = params[:scrim_id]
    return nil unless scrim_id.present?

    # ActionCable context doesn't go through authenticate_request!, so
    # Current.organization_id must be set manually for OrganizationScoped models.
    Current.organization_id = current_user.organization_id

    # Owner org — most common path
    scrim = current_user.organization.scrims.find_by(id: scrim_id)
    return scrim if scrim

    # Cross-org participant via ScrimRequest
    cross_org_scrim(scrim_id)
  end

  # Returns the scrim if the current user's org is the opposing participant
  # in the linked ScrimRequest. Returns nil otherwise.
  def cross_org_scrim(scrim_id)
    # Bypass OrganizationScoped — the scrim may belong to the opponent's org
    scrim = Scrim.unscoped_by_organization.find_by(id: scrim_id)
    return nil unless scrim

    request = scrim_request_for(scrim)
    return nil unless request

    org_id = current_user.organization_id
    return scrim if request.requesting_organization_id == org_id ||
                    request.target_organization_id == org_id

    nil
  end

  def scrim_request_for(scrim)
    return nil unless scrim.scrim_request_id.present?

    ScrimRequest.find_by(id: scrim.scrim_request_id)
  end

  # Uses ScrimRequest ID as canonical stream so both orgs share the same channel.
  # Falls back to per-scrim stream when no request is linked (manual scrims).
  def canonical_stream_name(scrim)
    if scrim.scrim_request_id.present?
      "scrim_request_chat_#{scrim.scrim_request_id}"
    else
      "scrim_chat_#{scrim.id}"
    end
  end
end
