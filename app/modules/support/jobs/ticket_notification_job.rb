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
      Notification.create!(
        user: user,
        title: 'Ticket Criado',
        message: "Seu ticket ##{ticket.ticket_number} foi criado com sucesso: #{ticket.subject}",
        type: 'info',
        link_url: "/support/tickets/#{ticket.id}",
        link_type: 'support_ticket',
        link_id: ticket.id,
        channels: ['in_app']
      )

      Rails.logger.info("Notification created for #{user.email}")
      Rails.logger.info("Ticket ##{ticket.ticket_number}: #{ticket.subject}")
    end

    def send_new_message_email(ticket, user, message_id)
      message = SupportTicketMessage.find(message_id)

      Notification.create!(
        user: user,
        title: 'Nova Mensagem no Ticket',
        message: "Ticket ##{ticket.ticket_number}: Nova resposta de #{message.user.full_name}",
        type: 'info',
        link_url: "/support/tickets/#{ticket.id}",
        link_type: 'support_ticket',
        link_id: ticket.id,
        channels: ['in_app']
      )

      Rails.logger.info("Notification created for #{user.email}")
      Rails.logger.info("Ticket ##{ticket.ticket_number}: New response from #{message.user.full_name}")
    end

    def send_status_changed_email(ticket, user)
      Notification.create!(
        user: user,
        title: 'Status do Ticket Alterado',
        message: "Ticket ##{ticket.ticket_number}: Status alterado para #{ticket.status}",
        type: 'info',
        link_url: "/support/tickets/#{ticket.id}",
        link_type: 'support_ticket',
        link_id: ticket.id,
        channels: ['in_app']
      )

      Rails.logger.info("Notification created for #{user.email}")
      Rails.logger.info("Ticket ##{ticket.ticket_number}: Status changed to #{ticket.status}")
    end

    def send_ticket_resolved_email(ticket, user)
      Notification.create!(
        user: user,
        title: 'Ticket Resolvido',
        message: "Ticket ##{ticket.ticket_number}: Seu ticket foi resolvido",
        type: 'success',
        link_url: "/support/tickets/#{ticket.id}",
        link_type: 'support_ticket',
        link_id: ticket.id,
        channels: ['in_app']
      )

      Rails.logger.info("Notification created for #{user.email}")
      Rails.logger.info("Ticket ##{ticket.ticket_number}: Your ticket has been resolved")
    end
  end
end
