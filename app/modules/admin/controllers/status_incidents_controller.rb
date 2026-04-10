# frozen_string_literal: true

module Admin
  module Controllers
    # Admin controller for managing status incidents.
    #
    # Allows admins to create, update, and communicate about service incidents
    # that appear on the public status page.
    #
    # All endpoints require admin or owner role.
    class StatusIncidentsController < Api::V1::BaseController
      before_action :require_admin_access
      before_action :set_incident, only: %i[show update add_update destroy]

      # GET /api/v1/admin/status/incidents
      def index
        incidents = StatusIncident.includes(:updates, :created_by)
                                  .recent
        result    = paginate(incidents)

        render_success(
          incidents: result[:data].map { |i| serialize_incident(i) },
          pagination: result[:pagination]
        )
      end

      # GET /api/v1/admin/status/incidents/:id
      def show
        render_success(incident: serialize_incident(@incident))
      end

      # POST /api/v1/admin/status/incidents
      def create
        incident = StatusIncident.new(create_params)
        incident.created_by_user_id = current_user.id

        incident.save!

        log_user_action(
          action: 'create_status_incident',
          entity_type: 'StatusIncident',
          entity_id: incident.id,
          new_values: create_params.to_h
        )

        render_created(incident: serialize_incident(incident), message: 'Incident created successfully')
      end

      # PATCH /api/v1/admin/status/incidents/:id
      def update
        old_values = @incident.slice(:title, :body, :severity, :status, :resolved_at, :postmortem)

        @incident.update!(update_params)

        log_user_action(
          action: 'update_status_incident',
          entity_type: 'StatusIncident',
          entity_id: @incident.id,
          old_values: old_values,
          new_values: update_params.to_h
        )

        render_updated(incident: serialize_incident(@incident))
      end

      # POST /api/v1/admin/status/incidents/:id/updates
      def add_update
        update_record = @incident.updates.build(add_update_params)
        update_record.created_by_user_id = current_user.id

        update_record.save!

        @incident.update_column(:status, update_record.status)

        log_user_action(
          action: 'add_incident_update',
          entity_type: 'StatusIncidentUpdate',
          entity_id: update_record.id,
          new_values: add_update_params.to_h
        )

        render_created(
          incident_update: serialize_update(update_record),
          message: 'Incident update added successfully'
        )
      end

      # DELETE /api/v1/admin/status/incidents/:id
      def destroy
        @incident.destroy!

        log_user_action(
          action: 'delete_status_incident',
          entity_type: 'StatusIncident',
          entity_id: @incident.id
        )

        render_deleted(message: 'Incident deleted successfully')
      end

      private

      def require_admin_access
        return if current_user&.admin? || current_user&.owner?

        render_error(
          message: 'Admin access required',
          code: 'FORBIDDEN',
          status: :forbidden
        )
      end

      def set_incident
        # StatusIncidents are platform-wide (not org-scoped) — intentionally unscoped.
        # This endpoint requires admin or owner role (see require_admin_access before_action).
        # nosemgrep: ruby.rails.security.brakeman.check-unscoped-find
        @incident = StatusIncident.find(params[:id])
      end

      def create_params
        params.require(:status_incident).permit(
          :title, :body, :severity, :started_at,
          affected_components: []
        )
      end

      def update_params
        params.require(:status_incident).permit(
          :title, :body, :severity, :status, :resolved_at, :postmortem
        )
      end

      def add_update_params
        params.require(:status_incident_update).permit(:status, :body)
      end

      def serialize_incident(incident)
        {
          id: incident.id,
          title: incident.title,
          body: incident.body,
          severity: incident.severity,
          status: incident.status,
          affected_components: incident.affected_components,
          started_at: incident.started_at.iso8601,
          resolved_at: incident.resolved_at&.iso8601,
          postmortem: incident.postmortem,
          created_by: if incident.created_by
                        { id: incident.created_by.id,
                          email: incident.created_by.email }
                      end,
          created_at: incident.created_at.iso8601,
          updated_at: incident.updated_at.iso8601,
          updates: incident.updates.order(created_at: :desc).map { |u| serialize_update(u) }
        }
      end

      def serialize_update(update_record)
        {
          id: update_record.id,
          status: update_record.status,
          body: update_record.body,
          created_by: if update_record.created_by
                        { id: update_record.created_by.id,
                          email: update_record.created_by.email }
                      end,
          created_at: update_record.created_at.iso8601
        }
      end
    end
  end
end
