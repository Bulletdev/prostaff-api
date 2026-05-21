# frozen_string_literal: true

# == Schema Information
#
# Table name: messages
#
#  id              :uuid             not null, primary key
#  user_id         :uuid             not null  (sender ID — User or Player)
#  sender_type     :string           default("User"), not null
#  recipient_id    :uuid                       (nil = broadcast; present = DM)
#  recipient_type  :string           default("User"), not null
#  organization_id :uuid             not null
#  content         :text             not null
#  deleted         :boolean          default(false), not null
#  deleted_at      :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Message < ApplicationRecord
  PARTICIPANT_TYPES = %w[User Player].freeze

  # Associations
  # user_id stores the sender ID regardless of whether sender is a User or Player.
  # FK to users table was removed in migration RemoveMessagesUserForeignKeys.
  belongs_to :organization

  # Validations
  validates :user_id, presence: true
  validates :content, presence: true, length: { minimum: 1, maximum: 2000 }
  validates :sender_type, inclusion: { in: PARTICIPANT_TYPES }
  validates :recipient_type, inclusion: { in: PARTICIPANT_TYPES }, allow_nil: true
  validate  :recipient_belongs_to_same_org, if: -> { recipient_id.present? }

  # Scopes
  scope :active,           -> { where(deleted: false) }
  scope :for_organization, ->(org_id) { where(organization_id: org_id) }
  scope :chronological,    -> { order(created_at: :asc) }
  scope :recent_first,     -> { order(created_at: :desc) }

  # Returns the full conversation between two participants (both directions)
  scope :conversation_between, lambda { |participant_a_id, participant_b_id|
    where(
      '(user_id = ? AND recipient_id = ?) OR (user_id = ? AND recipient_id = ?)',
      participant_a_id, participant_b_id, participant_b_id, participant_a_id
    )
  }

  # Callbacks
  after_create_commit :broadcast_to_participants

  # Returns a deterministic, symmetric stream key for a DM conversation.
  # Sorting the two IDs ensures A→B and B→A share the same stream.
  def self.dm_stream_key(participant_a_id, participant_b_id, org_id)
    pair = [participant_a_id.to_s, participant_b_id.to_s].sort.join('_')
    "dm_#{pair}_org_#{org_id}"
  end

  # Soft delete — preserves conversation history
  def soft_delete!
    update!(deleted: true, deleted_at: Time.current)
    broadcast_deletion
  end

  # Returns the sender record (User or Player)
  def sender_record
    find_sender_record
  end

  # Returns the recipient record (User or Player)
  def recipient_record
    find_recipient_record
  end

  private

  def recipient_belongs_to_same_org
    record = find_recipient_record
    return if record&.organization_id == organization_id

    errors.add(:recipient, 'must belong to the same organization')
  end

  def find_sender_record
    if sender_type == 'Player'
      Player.find_by(id: user_id)
    else
      User.find_by(id: user_id)
    end
  end

  def find_recipient_record
    if recipient_type == 'Player'
      Player.find_by(id: recipient_id)
    else
      User.find_by(id: recipient_id)
    end
  end

  def broadcast_to_participants
    return unless recipient_id.present?

    stream = Message.dm_stream_key(user_id, recipient_id, organization_id)
    ActionCable.server.broadcast(stream, {
                                   type: 'new_message',
                                   message: serialize_for_broadcast
                                 })
  end

  def broadcast_deletion
    return unless recipient_id.present?

    stream = Message.dm_stream_key(user_id, recipient_id, organization_id)
    ActionCable.server.broadcast(stream, {
                                   type: 'message_deleted',
                                   message_id: id
                                 })
  end

  def serialize_for_broadcast
    sender = find_sender_record
    {
      id: id,
      content: content,
      created_at: created_at.iso8601,
      recipient_id: recipient_id,
      recipient_type: recipient_type,
      sender_type: sender_type,
      sender: serialize_sender_for_broadcast(sender)
    }
  end

  def serialize_sender_for_broadcast(sender)
    return {} unless sender

    if sender_type == 'Player'
      { id: sender.id, full_name: sender.professional_name.presence || sender.real_name, role: sender.role }
    else
      { id: sender.id, full_name: sender.full_name, role: sender.role }
    end
  end
end
