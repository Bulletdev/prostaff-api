# frozen_string_literal: true

module Support
  # Job to notify support staff about ticket activities
  class StaffNotificationJob < ApplicationJob
    queue_as :default

    def perform(ticket_id, notification_type, message_id = nil)
      ticket = SupportTicket.find(ticket_id)

      case notification_type
      when 'new_ticket'
        notify_staff_new_ticket(ticket)
      when 'new_user_message'
        notify_assigned_staff(ticket, message_id)
      when 'urgent_ticket'
        notify_all_staff_urgent(ticket)
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("Ticket #{ticket_id} not found for staff notification")
    end

    private

    def notify_staff_new_ticket(ticket)
      # Notify available support staff
      staff_users = User.where(role: %w[support_staff admin])

      staff_users.each do |staff|
        Rails.logger.info("📧 Notifying staff #{staff.email} about new ticket")
        Rails.logger.info("   Ticket ##{ticket.ticket_number}: #{ticket.subject}")
        # StaffMailer.new_ticket(ticket, staff).deliver_later
      end
    end

    def notify_assigned_staff(ticket, message_id)
      return unless ticket.assigned_to

      message = SupportTicketMessage.find(message_id)

      Rails.logger.info("📧 Notifying assigned staff #{ticket.assigned_to.email}")
      Rails.logger.info("   Ticket ##{ticket.ticket_number}: New message from #{message.user.full_name}")

      # StaffMailer.new_user_message(ticket, ticket.assigned_to, message).deliver_later
    end

    def notify_all_staff_urgent(ticket)
      staff_users = User.where(role: %w[support_staff admin])

      staff_users.each do |staff|
        Rails.logger.warn("⚠️  URGENT: Notifying #{staff.email}")
        Rails.logger.warn("   Ticket ##{ticket.ticket_number}: #{ticket.subject}")
        # StaffMailer.urgent_ticket(ticket, staff).deliver_later
      end
    end
  end
end
