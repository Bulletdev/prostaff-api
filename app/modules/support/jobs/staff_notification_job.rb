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
      User.where(role: %w[support_staff admin]).each do |staff|
        notify_staff(staff, ticket: ticket,
                            title: 'Novo Ticket de Suporte',
                            message: "Ticket ##{ticket.ticket_number}: #{ticket.subject}",
                            notification_type: 'info')
        Rails.logger.info("Notification created for staff #{staff.email}")
        Rails.logger.info("Ticket ##{ticket.ticket_number}: #{ticket.subject}")
      end
    end

    def notify_assigned_staff(ticket, message_id)
      return unless ticket.assigned_to

      message = SupportTicketMessage.find(message_id)
      user_name = message.user.full_name
      notify_staff(ticket.assigned_to, ticket: ticket,
                                       title: 'Nova Mensagem de Usuario',
                                       message: "Ticket ##{ticket.ticket_number}: Nova mensagem de #{user_name}",
                                       notification_type: 'info')
      Rails.logger.info("Notification created for assigned staff #{ticket.assigned_to.email}")
      Rails.logger.info("Ticket ##{ticket.ticket_number}: New message from #{message.user.full_name}")
    end

    def notify_all_staff_urgent(ticket)
      User.where(role: %w[support_staff admin]).each do |staff|
        notify_staff(staff, ticket: ticket,
                            title: 'URGENTE: Ticket Prioritario',
                            message: "Ticket ##{ticket.ticket_number}: #{ticket.subject}",
                            notification_type: 'error')
        Rails.logger.warn("URGENT: Notification created for #{staff.email}")
        Rails.logger.warn("Ticket ##{ticket.ticket_number}: #{ticket.subject}")
      end
    end

    def notify_staff(user, ticket:, title:, message:, notification_type:)
      Notification.create!(
        user: user,
        title: title,
        message: message,
        type: notification_type,
        link_url: "/support/tickets/#{ticket.id}",
        link_type: 'support_ticket',
        link_id: ticket.id,
        channels: ['in_app']
      )
    end
  end
end
