# frozen_string_literal: true

# == Schema Information
#
# Table name: support_ticket_messages
#
#  id                :uuid             not null, primary key
#  support_ticket_id :uuid             not null
#  user_id           :uuid             not null
#  content           :text             not null
#  message_type      :string           default("user"), not null
#  is_internal       :boolean          default(FALSE)
#  attachments       :jsonb
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class SupportTicketMessage < ApplicationRecord
  # Associations
  belongs_to :support_ticket
  belongs_to :user

  # Validations
  validates :content, presence: true, length: { minimum: 1 }
  validates :message_type, presence: true, inclusion: {
    in: %w[user staff system chatbot]
  }

  # Scopes
  scope :user_visible, -> { where(is_internal: false) }
  scope :staff_only, -> { where(is_internal: true) }
  scope :by_type, ->(type) { where(message_type: type) }
  scope :chronological, -> { order(created_at: :asc) }

  # Callbacks
  after_create :notify_participants

  private

  def notify_participants
    # Notify ticket owner if message is from staff
    if message_type == 'staff' && user_id != support_ticket.user_id
      Support::TicketNotificationJob.perform_later(
        support_ticket.id,
        'new_message',
        id
      )
    end

    # Notify assigned staff if message is from user
    if message_type == 'user' && support_ticket.assigned_to_id.present?
      Support::StaffNotificationJob.perform_later(
        support_ticket.id,
        'new_user_message',
        id
      )
    end
  end
end
