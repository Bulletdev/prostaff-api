# frozen_string_literal: true

# == Schema Information
#
# Table name: support_tickets
#
#  id                  :uuid             not null, primary key
#  user_id             :uuid             not null
#  organization_id     :uuid             not null
#  assigned_to_id      :uuid
#  subject             :string           not null
#  description         :text             not null
#  category            :string           not null
#  priority            :string           default("medium"), not null
#  status              :string           default("open"), not null
#  page_url            :string
#  context_data        :jsonb
#  chatbot_attempted   :boolean          default(FALSE)
#  chatbot_suggestions :jsonb
#  first_response_at   :datetime
#  resolved_at         :datetime
#  closed_at           :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  deleted_at          :datetime
#
class SupportTicket < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :organization
  belongs_to :assigned_to, class_name: 'User', optional: true
  has_many :messages, class_name: 'SupportTicketMessage', dependent: :destroy

  # Validations
  validates :subject, presence: true, length: { minimum: 5, maximum: 200 }
  validates :description, presence: true, length: { minimum: 10 }
  validates :category, presence: true, inclusion: {
    in: %w[technical feature_request billing riot_integration other]
  }
  validates :priority, presence: true, inclusion: {
    in: %w[low medium high urgent]
  }
  validates :status, presence: true, inclusion: {
    in: %w[open in_progress waiting_client resolved closed]
  }

  # Scopes
  scope :open_tickets, -> { where(status: %w[open in_progress waiting_client]) }
  scope :closed_tickets, -> { where(status: %w[resolved closed]) }
  scope :unassigned, -> { where(assigned_to_id: nil) }
  scope :assigned, -> { where.not(assigned_to_id: nil) }
  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END")) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_create :set_ticket_number
  after_update :track_status_changes

  # Instance methods
  def ticket_number
    "TICKET-#{id&.split('-')&.first&.upcase || 'DRAFT'}"
  end

  def assign_to!(user)
    update!(assigned_to: user, status: 'in_progress')
    create_system_message("Ticket atribuído para #{user.full_name}")
  end

  def resolve!(resolution_note = nil)
    update!(
      status: 'resolved',
      resolved_at: Time.current
    )
    create_system_message(resolution_note || 'Ticket marcado como resolvido')
  end

  def close!
    update!(
      status: 'closed',
      closed_at: Time.current
    )
    create_system_message('Ticket fechado')
  end

  def reopen!
    update!(
      status: 'open',
      resolved_at: nil,
      closed_at: nil
    )
    create_system_message('Ticket reaberto')
  end

  def response_time
    return nil unless first_response_at

    first_response_at - created_at
  end

  def resolution_time
    return nil unless resolved_at

    resolved_at - created_at
  end

  private

  def set_ticket_number
    # Ticket number will be generated after creation when ID is available
    true
  end

  def track_status_changes
    if saved_change_to_status?
      previous_status = saved_changes['status'][0]
      new_status = saved_changes['status'][1]

      # Track first response
      if first_response_at.nil? && new_status == 'in_progress'
        update_column(:first_response_at, Time.current)
      end

      # Track resolution
      if resolved_at.nil? && new_status == 'resolved'
        update_column(:resolved_at, Time.current)
      end

      # Track closure
      if closed_at.nil? && new_status == 'closed'
        update_column(:closed_at, Time.current)
      end
    end
  end

  def create_system_message(content)
    messages.create!(
      user: User.system_user, # You'll need to create a system user
      content: content,
      message_type: 'system'
    )
  rescue StandardError => e
    Rails.logger.error("Failed to create system message: #{e.message}")
  end
end
