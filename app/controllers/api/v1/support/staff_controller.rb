# frozen_string_literal: true

module Api
  module V1
    module Support
      # Controller for support staff operations
      class StaffController < Api::V1::BaseController
        before_action :require_support_staff
        before_action :set_ticket, only: %i[assign resolve]

        # GET /api/v1/support/staff/dashboard
        def dashboard
          stats = calculate_dashboard_stats

          render_success({ stats: stats })
        end

        # POST /api/v1/support/staff/tickets/:id/assign
        def assign
          staff_member = User.find_by!(id: params[:assigned_to_id])

          unless staff_member.support_staff? || staff_member.admin?
            return render_error('User is not support staff', :unprocessable_entity)
          end

          @ticket.assign_to!(staff_member)

          # Log action
          log_user_action(
            action: 'assign_ticket',
            entity_type: 'SupportTicket',
            entity_id: @ticket.id,
            new_values: { assigned_to_id: staff_member.id }
          )

          render_success({ ticket: serialize_ticket(@ticket) })
        end

        # POST /api/v1/support/staff/tickets/:id/resolve
        def resolve
          resolution_note = params[:resolution_note]

          @ticket.resolve!(resolution_note)

          # Log action
          log_user_action(
            action: 'resolve_ticket',
            entity_type: 'SupportTicket',
            entity_id: @ticket.id,
            new_values: { status: 'resolved', resolution_note: resolution_note }
          )

          render_success({ ticket: serialize_ticket(@ticket) })
        end

        # GET /api/v1/support/staff/analytics
        def analytics
          date_range = parse_date_range

          analytics_data = {
            tickets_created: tickets_in_range(date_range).count,
            tickets_resolved: tickets_resolved_in_range(date_range).count,
            avg_response_time: calculate_avg_response_time(date_range),
            avg_resolution_time: calculate_avg_resolution_time(date_range),
            by_category: tickets_by_category(date_range),
            by_priority: tickets_by_priority(date_range),
            resolution_rate: calculate_resolution_rate(date_range),
            trending_issues: identify_trending_issues(date_range)
          }

          render_success({ analytics: analytics_data })
        end

        private

        def require_support_staff
          unless current_user.support_staff? || current_user.admin?
            render_error('Unauthorized - Support staff only', :unauthorized)
          end
        end

        def set_ticket
          @ticket = SupportTicket.find_by!(id: params[:id])
        rescue ActiveRecord::RecordNotFound
          render_error('Ticket not found', :not_found)
        end

        def calculate_dashboard_stats
          {
            total_tickets: SupportTicket.count,
            open: SupportTicket.where(status: 'open').count,
            in_progress: SupportTicket.where(status: 'in_progress').count,
            waiting_client: SupportTicket.where(status: 'waiting_client').count,
            resolved_today: SupportTicket.where('resolved_at >= ?', Time.current.beginning_of_day).count,
            unassigned: SupportTicket.unassigned.open_tickets.count,
            my_tickets: SupportTicket.where(assigned_to: current_user).open_tickets.count,
            avg_response_time_today: calculate_avg_response_time(Time.current.beginning_of_day..Time.current),
            high_priority: SupportTicket.where(priority: 'high').open_tickets.count,
            urgent: SupportTicket.where(priority: 'urgent').open_tickets.count
          }
        end

        def parse_date_range
          start_date = params[:start_date] ? Time.zone.parse(params[:start_date]) : 30.days.ago
          end_date = params[:end_date] ? Time.zone.parse(params[:end_date]) : Time.current
          start_date..end_date
        end

        def tickets_in_range(range)
          SupportTicket.where(created_at: range)
        end

        def tickets_resolved_in_range(range)
          SupportTicket.where(resolved_at: range)
        end

        def calculate_avg_response_time(range)
          tickets = tickets_in_range(range).where.not(first_response_at: nil)
          return 0 if tickets.empty?

          total_time = tickets.sum { |t| t.response_time || 0 }
          (total_time / tickets.count / 3600.0).round(2) # in hours
        end

        def calculate_avg_resolution_time(range)
          tickets = tickets_resolved_in_range(range)
          return 0 if tickets.empty?

          total_time = tickets.sum { |t| t.resolution_time || 0 }
          (total_time / tickets.count / 3600.0).round(2) # in hours
        end

        def tickets_by_category(range)
          tickets_in_range(range).group(:category).count
        end

        def tickets_by_priority(range)
          tickets_in_range(range).group(:priority).count
        end

        def calculate_resolution_rate(range)
          created = tickets_in_range(range).count
          return 0 if created.zero?

          resolved = tickets_resolved_in_range(range).count
          ((resolved.to_f / created) * 100).round(1)
        end

        def identify_trending_issues(range)
          # Group by category and count
          tickets_in_range(range)
            .group(:category)
            .order('count_all DESC')
            .limit(5)
            .count
        end

        def serialize_ticket(ticket)
          # Reuse from TicketsController or move to serializer
          {
            id: ticket.id,
            ticket_number: ticket.ticket_number,
            subject: ticket.subject,
            status: ticket.status,
            priority: ticket.priority,
            category: ticket.category,
            assigned_to: ticket.assigned_to ? {
              id: ticket.assigned_to.id,
              name: ticket.assigned_to.full_name
            } : nil,
            created_at: ticket.created_at.iso8601
          }
        end
      end
    end
  end
end
