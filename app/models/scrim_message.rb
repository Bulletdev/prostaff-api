# frozen_string_literal: true

# Model representing a chat message sent within a scrim session.
#
# ScrimMessage supports cross-organization communication between the two teams
# participating in a scrim. Each message is scoped to a specific scrim and
# retains the sender's organization for display purposes.
#
# Soft-deletion is used so that the conversation history remains consistent
# for other participants after a message is removed.
#
# @example Create a message
#   ScrimMessage.create!(
#     scrim: scrim,
#     user: current_user,
#     organization: current_user.organization,
#     content: 'gg wp'
#   )
class ScrimMessage < ApplicationRecord
  MAX_CONTENT_LENGTH = 1000

  # Associations
  belongs_to :scrim
  belongs_to :user
  belongs_to :organization

  # Validations
  validates :content, presence: true, length: { maximum: MAX_CONTENT_LENGTH }

  # Scopes
  scope :active, -> { where(deleted: false) }
  scope :chronological, -> { order(created_at: :asc) }

  # Callbacks
  after_create_commit :broadcast_to_scrim

  # Marks the message as deleted without removing the record from the database.
  #
  # @return [void]
  def soft_delete!
    update!(deleted: true, deleted_at: Time.current)
  end

  private

  def broadcast_to_scrim
    broadcast_via_action_cable
    notify_discord
  end

  def broadcast_via_action_cable
    stream = if scrim.scrim_request_id.present?
               "scrim_request_chat_#{scrim.scrim_request_id}"
             else
               "scrim_chat_#{scrim_id}"
             end
    ActionCable.server.broadcast(stream, cable_payload)
  rescue StandardError => e
    Rails.logger.error "[ScrimMessage] Action Cable broadcast failed for scrim=#{scrim_id}: #{e.message}"
  end

  def notify_discord
    DiscordWebhookService.notify_new_message(self)
  rescue StandardError => e
    Rails.logger.warn "[ScrimMessage] Discord notification failed for scrim=#{scrim_id}: #{e.message}"
  end

  def cable_payload
    {
      type: 'new_message',
      message: {
        id: id,
        content: content,
        created_at: created_at.iso8601,
        user: { id: user.id, full_name: user.full_name },
        organization: { id: organization_id, name: organization.name }
      }
    }
  end
end
