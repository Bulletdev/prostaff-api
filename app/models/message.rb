# frozen_string_literal: true

# == Schema Information
#
# Table name: messages
#
#  id              :uuid             not null, primary key
#  user_id         :uuid             not null  (sender)
#  recipient_id    :uuid                       (nil = not used; present = DM)
#  organization_id :uuid             not null
#  content         :text             not null
#  deleted         :boolean          default(false), not null
#  deleted_at      :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Message < ApplicationRecord
  # Associations
  belongs_to :user                                              # sender
  belongs_to :recipient, class_name: 'User', optional: true   # DM target
  belongs_to :organization

  # Validations
  validates :content, presence: true, length: { minimum: 1, maximum: 2000 }
  validate  :recipient_belongs_to_same_org, if: -> { recipient_id.present? }

  # Scopes
  scope :active,           -> { where(deleted: false) }
  scope :for_organization, ->(org_id) { where(organization_id: org_id) }
  scope :chronological,    -> { order(created_at: :asc) }
  scope :recent_first,     -> { order(created_at: :desc) }

  # Returns the full conversation between two users (both directions)
  scope :conversation_between, ->(user_a_id, user_b_id) {
    where(
      '(user_id = ? AND recipient_id = ?) OR (user_id = ? AND recipient_id = ?)',
      user_a_id, user_b_id, user_b_id, user_a_id
    )
  }

  # Callbacks
  after_create_commit :broadcast_to_participants

  # Returns a deterministic, symmetric stream key for a DM conversation.
  # Sorting the two IDs ensures user A→B and B→A share the same stream.
  def self.dm_stream_key(user_a_id, user_b_id, org_id)
    pair = [user_a_id.to_s, user_b_id.to_s].sort.join('_')
    "dm_#{pair}_org_#{org_id}"
  end

  # Soft delete — preserves conversation history
  def soft_delete!
    update!(deleted: true, deleted_at: Time.current)
    broadcast_deletion
  end

  private

  def recipient_belongs_to_same_org
    return unless recipient
    unless recipient.organization_id == organization_id
      errors.add(:recipient, 'must belong to the same organization')
    end
  end

  def broadcast_to_participants
    return unless recipient_id.present?

    stream = Message.dm_stream_key(user_id, recipient_id, organization_id)
    ActionCable.server.broadcast(stream, {
      type:    'new_message',
      message: serialize_for_broadcast
    })
  end

  def broadcast_deletion
    return unless recipient_id.present?

    stream = Message.dm_stream_key(user_id, recipient_id, organization_id)
    ActionCable.server.broadcast(stream, {
      type:       'message_deleted',
      message_id: id
    })
  end

  def serialize_for_broadcast
    {
      id:           id,
      content:      content,
      created_at:   created_at.iso8601,
      recipient_id: recipient_id,
      user: {
        id:        user.id,
        full_name: user.full_name,
        role:      user.role
      }
    }
  end
end
