# frozen_string_literal: true

module Support
  # Job to send ticket notifications to users
  class TicketNotificationJob < ApplicationJob
    queue_as :default

    def perform(ticket_id, notification_type, message_id = nil)
      ticket = SupportTicket.find(ticket_id)
      user = ticket.user

      case notification_type
      when 'created'
        send_ticket_created_email(ticket, user)
      when 'new_message'
        send_new_message_email(ticket, user, message_id)
      when 'status_changed'
        send_status_changed_email(ticket, user)
      when 'resolved'
        send_ticket_resolved_email(ticket, user)
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("Ticket #{ticket_id} not found for notification")
    end

    private

    def send_ticket_created_email(ticket, user)
      # TODO: Replace with actual mailer
      Rails.logger.info("📧 Sending ticket created email to #{user.email}")
      Rails.logger.info("   Ticket ##{ticket.ticket_number}: #{ticket.subject}")

      # SupportMailer.ticket_created(ticket, user).deliver_later
    end

    def send_new_message_email(ticket, user, message_id)
      message = SupportTicketMessage.find(message_id)

      Rails.logger.info("📧 Sending new message notification to #{user.email}")
      Rails.logger.info("   Ticket ##{ticket.ticket_number}: New response from #{message.user.full_name}")

      # SupportMailer.new_message(ticket, user, message).deliver_later
    end

    def send_status_changed_email(ticket, user)
      Rails.logger.info("📧 Sending status change notification to #{user.email}")
      Rails.logger.info("   Ticket ##{ticket.ticket_number}: Status changed to #{ticket.status}")

      # SupportMailer.status_changed(ticket, user).deliver_later
    end

    def send_ticket_resolved_email(ticket, user)
      Rails.logger.info("📧 Sending resolution notification to #{user.email}")
      Rails.logger.info("   Ticket ##{ticket.ticket_number}: Your ticket has been resolved")

      # SupportMailer.ticket_resolved(ticket, user).deliver_later
    end
  end
end
