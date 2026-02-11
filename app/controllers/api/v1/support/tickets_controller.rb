# frozen_string_literal: true

module Api
  module V1
    module Support
      # Controller for support ticket management
      class TicketsController < Api::V1::BaseController
        before_action :set_ticket, only: %i[show update add_message close reopen]

        # GET /api/v1/support/tickets
        def index
          tickets = current_user.admin? || current_user.support_staff? ?
                    SupportTicket.all :
                    SupportTicket.where(user: current_user)

          tickets = apply_filters(tickets)
          tickets = tickets.includes(:user, :organization, :assigned_to)
                          .order(created_at: :desc)

          result = paginate(tickets)

          render_success({
            tickets: result[:data].map { |t| serialize_ticket(t) },
            pagination: result[:pagination],
            summary: {
              total: tickets.count,
              open: tickets.where(status: 'open').count,
              in_progress: tickets.where(status: 'in_progress').count,
              resolved: tickets.where(status: 'resolved').count
            }
          })
        end

        # GET /api/v1/support/tickets/:id
        def show
          authorize_ticket_access!

          render_success({
            ticket: serialize_ticket_detail(@ticket)
          })
        end

        # POST /api/v1/support/tickets
        def create
          ticket = SupportTicket.new(ticket_params)
          ticket.user = current_user
          ticket.organization = current_organization

          # Run chatbot if description provided
          if ticket.description.present?
            chatbot_result = Support::ChatbotService.new(ticket).generate_suggestions
            ticket.chatbot_attempted = true
            ticket.chatbot_suggestions = chatbot_result[:suggestions]
          end

          if ticket.save
            # Send notification
            Support::TicketNotificationJob.perform_later(ticket.id, 'created')

            render_success(
              { ticket: serialize_ticket_detail(ticket) },
              :created
            )
          else
            render_error(ticket.errors.full_messages.join(', '), :unprocessable_entity)
          end
        end

        # PATCH /api/v1/support/tickets/:id
        def update
          authorize_ticket_access!

          if @ticket.update(update_ticket_params)
            render_success({ ticket: serialize_ticket_detail(@ticket) })
          else
            render_error(@ticket.errors.full_messages.join(', '), :unprocessable_entity)
          end
        end

        # POST /api/v1/support/tickets/:id/messages
        def add_message
          authorize_ticket_access!

          message = @ticket.messages.build(message_params)
          message.user = current_user
          message.message_type = current_user.support_staff? ? 'staff' : 'user'

          if message.save
            render_success({ message: serialize_message(message) }, :created)
          else
            render_error(message.errors.full_messages.join(', '), :unprocessable_entity)
          end
        end

        # POST /api/v1/support/tickets/:id/close
        def close
          authorize_ticket_access!

          @ticket.close!
          render_success({ ticket: serialize_ticket(@ticket) })
        end

        # POST /api/v1/support/tickets/:id/reopen
        def reopen
          authorize_ticket_access!

          @ticket.reopen!
          render_success({ ticket: serialize_ticket(@ticket) })
        end

        private

        def set_ticket
          @ticket = SupportTicket.find_by!(id: params[:id])
        rescue ActiveRecord::RecordNotFound
          render_error('Ticket not found', :not_found)
        end

        def authorize_ticket_access!
          unless can_access_ticket?(@ticket)
            render_error('Unauthorized', :unauthorized)
          end
        end

        def can_access_ticket?(ticket)
          current_user.admin? ||
            current_user.support_staff? ||
            ticket.user_id == current_user.id ||
            ticket.assigned_to_id == current_user.id
        end

        def apply_filters(scope)
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.where(category: params[:category]) if params[:category].present?
          scope = scope.where(priority: params[:priority]) if params[:priority].present?
          scope = scope.where(assigned_to_id: current_user.id) if params[:assigned_to_me] == 'true'
          scope
        end

        def ticket_params
          params.require(:ticket).permit(
            :subject,
            :description,
            :category,
            :priority,
            :page_url,
            context_data: {}
          )
        end

        def update_ticket_params
          params.require(:ticket).permit(:priority, :status)
        end

        def message_params
          params.require(:message).permit(:content, :is_internal, attachments: [])
        end

        def serialize_ticket(ticket)
          {
            id: ticket.id,
            ticket_number: ticket.ticket_number,
            subject: ticket.subject,
            category: ticket.category,
            priority: ticket.priority,
            status: ticket.status,
            user: {
              id: ticket.user.id,
              name: ticket.user.full_name,
              email: ticket.user.email
            },
            organization: {
              id: ticket.organization.id,
              name: ticket.organization.name
            },
            assigned_to: ticket.assigned_to ? {
              id: ticket.assigned_to.id,
              name: ticket.assigned_to.full_name
            } : nil,
            created_at: ticket.created_at.iso8601,
            updated_at: ticket.updated_at.iso8601
          }
        end

        def serialize_ticket_detail(ticket)
          serialize_ticket(ticket).merge(
            description: ticket.description,
            page_url: ticket.page_url,
            context_data: ticket.context_data,
            chatbot_suggestions: ticket.chatbot_suggestions,
            messages: ticket.messages.user_visible.chronological.map { |m| serialize_message(m) },
            metrics: {
              response_time: ticket.response_time,
              resolution_time: ticket.resolution_time
            }
          )
        end

        def serialize_message(message)
          {
            id: message.id,
            content: message.content,
            message_type: message.message_type,
            user: {
              id: message.user.id,
              name: message.user.full_name
            },
            created_at: message.created_at.iso8601
          }
        end
      end
    end
  end
end
