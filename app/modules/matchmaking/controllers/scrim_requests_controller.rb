# frozen_string_literal: true

module Matchmaking
  module Controllers
    # Handles scrim request lifecycle: create, accept, decline, cancel.
    class ScrimRequestsController < Api::V1::BaseController
      before_action :set_request, only: %i[show accept decline cancel]

      # GET /api/v1/matchmaking/scrim-requests
      def index
        requests = ScrimRequest.for_organization(current_organization.id)
                               .includes(:requesting_organization, :target_organization)
                               .recent

        if params[:status].present? && ScrimRequest::STATUSES.include?(params[:status])
          requests = requests.where(status: params[:status])
        end

        sent     = requests.sent_by(current_organization.id)
        received = requests.received_by(current_organization.id)

        render_success({
                         sent: ScrimRequestSerializer.render_as_hash(sent),
                         received: ScrimRequestSerializer.render_as_hash(received),
                         pending_count: received.pending.count
                       })
      end

      # GET /api/v1/matchmaking/suggestions
      def suggestions
        service = MatchSuggestionService.new(
          current_organization,
          game: params[:game] || 'league_of_legends',
          region: params[:region]
        )
        suggestions = params[:available_now] == 'true' ? service.available_now : service.suggestions
        render_success({ suggestions: suggestions })
      end

      # GET /api/v1/matchmaking/scrim-requests/:id
      def show
        render_success({ scrim_request: ScrimRequestSerializer.render_as_hash(@scrim_request) })
      end

      # POST /api/v1/matchmaking/scrim-requests
      def create
        target_org = Organization.find_by(id: params.dig(:scrim_request, :target_organization_id))

        unless target_org
          return render_error(message: 'Target organization not found', code: 'NOT_FOUND', status: :not_found)
        end

        if target_org.id == current_organization.id
          return render_error(message: 'Cannot send a scrim request to yourself',
                              code: 'INVALID_TARGET', status: :unprocessable_entity)
        end

        existing = ScrimRequest.pending
                               .where(requesting_organization_id: current_organization.id,
                                      target_organization_id: target_org.id)
                               .exists?

        if existing
          return render_error(message: 'A pending request to this organization already exists',
                              code: 'DUPLICATE_REQUEST', status: :unprocessable_entity)
        end

        request = ScrimRequest.new(
          requesting_organization: current_organization,
          target_organization: target_org,
          game: params.dig(:scrim_request, :game) || 'league_of_legends',
          message: params.dig(:scrim_request, :message),
          proposed_at: params.dig(:scrim_request, :proposed_at),
          games_planned: params.dig(:scrim_request, :games_planned) || 3,
          draft_type: params.dig(:scrim_request, :draft_type),
          availability_window_id: params.dig(:scrim_request, :availability_window_id),
          expires_at: 72.hours.from_now
        )

        if request.save
          render_created({ scrim_request: ScrimRequestSerializer.render_as_hash(request) },
                         message: 'Scrim request sent')
        else
          render_error(message: 'Failed to send scrim request', code: 'VALIDATION_ERROR',
                       status: :unprocessable_entity, details: request.errors.as_json)
        end
      end

      # PATCH /api/v1/matchmaking/scrim-requests/:id/accept
      def accept
        unless @scrim_request.target_organization_id == current_organization.id
          return render_error(message: 'Only the target organization can accept this request',
                              code: 'FORBIDDEN', status: :forbidden)
        end

        unless @scrim_request.pending?
          return render_error(message: "Request is #{@scrim_request.status}, cannot accept",
                              code: 'INVALID_STATE', status: :unprocessable_entity)
        end

        if @scrim_request.accept!(accepting_org: current_organization)
          notify_discord(:accepted, @scrim_request)
          render_success({ scrim_request: ScrimRequestSerializer.render_as_hash(@scrim_request.reload) },
                         message: 'Scrim request accepted! Scrim added to your schedule.')
        else
          render_error(message: 'Failed to accept scrim request', code: 'ACCEPT_ERROR',
                       status: :unprocessable_entity)
        end
      end

      # PATCH /api/v1/matchmaking/scrim-requests/:id/decline
      def decline
        unless @scrim_request.target_organization_id == current_organization.id
          return render_error(message: 'Only the target organization can decline this request',
                              code: 'FORBIDDEN', status: :forbidden)
        end

        unless @scrim_request.pending?
          return render_error(message: "Request is #{@scrim_request.status}, cannot decline",
                              code: 'INVALID_STATE', status: :unprocessable_entity)
        end

        if @scrim_request.decline!(declining_org: current_organization)
          notify_discord(:declined, @scrim_request)
          render_success({ scrim_request: ScrimRequestSerializer.render_as_hash(@scrim_request.reload) },
                         message: 'Scrim request declined')
        else
          render_error(message: 'Failed to decline scrim request', code: 'DECLINE_ERROR',
                       status: :unprocessable_entity)
        end
      end

      # PATCH /api/v1/matchmaking/scrim-requests/:id/cancel
      def cancel
        unless @scrim_request.requesting_organization_id == current_organization.id
          return render_error(message: 'Only the requesting organization can cancel this request',
                              code: 'FORBIDDEN', status: :forbidden)
        end

        if @scrim_request.cancel!(cancelling_org: current_organization)
          render_success({ scrim_request: ScrimRequestSerializer.render_as_hash(@scrim_request.reload) },
                         message: 'Scrim request cancelled')
        else
          render_error(message: 'Failed to cancel scrim request', code: 'CANCEL_ERROR',
                       status: :unprocessable_entity)
        end
      end

      private

      def set_request
        # Scoped to the current org via for_organization — only the org's own requests are accessible.
        @scrim_request = ScrimRequest.for_organization(current_organization.id).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def notify_discord(event, scrim_request)
        case event
        when :accepted then DiscordNotificationService.notify_accepted(scrim_request)
        when :declined then DiscordNotificationService.notify_declined(scrim_request)
        end
      rescue StandardError => e
        Rails.logger.warn "[DiscordNotification] Failed to notify #{event}: #{e.message}"
      end
    end
  end
end
