# frozen_string_literal: true

module Scrims
  module Controllers
    # Handles submission and retrieval of scrim series result reports.
    #
    # POST   /api/v1/scrims/scrims/:scrim_id/result — submit outcome
    # GET    /api/v1/scrims/scrims/:scrim_id/result — fetch current report status
    class ScrimResultReportsController < Api::V1::BaseController
      before_action :set_authorized_scrim
      before_action :set_scrim_request

      # GET /api/v1/scrims/scrims/:scrim_id/result
      def show
        my_report       = report_for(current_organization)
        opponent_report = report_for(opponent_organization)

        render_success({
                         my_report: serialize_report(my_report),
                         opponent_report: serialize_opponent_report(opponent_report),
                         status: combined_status(my_report, opponent_report),
                         deadline_at: my_report&.deadline_at&.iso8601,
                         attempts_remaining: my_report ? my_report.attempts_remaining : ScrimResultReport::MAX_ATTEMPTS,
                         max_attempts: ScrimResultReport::MAX_ATTEMPTS,
                         games_planned: @scrim_request&.games_planned
                       })
      end

      # POST /api/v1/scrims/scrims/:scrim_id/result
      def create
        unless @scrim_request
          return render_error(
            message: 'This scrim is not linked to a matchmaking request and cannot use cross-org result reporting.',
            code: 'NO_SCRIM_REQUEST',
            status: :unprocessable_entity
          )
        end

        outcomes = params[:game_outcomes]
        unless outcomes.is_a?(Array) && outcomes.present?
          return render_error(
            message: 'game_outcomes must be a non-empty array of "win"/"loss" values',
            code: 'INVALID_PARAMS',
            status: :unprocessable_entity
          )
        end

        result = ScrimResultValidationService.new(
          scrim_request: @scrim_request,
          organization: current_organization,
          game_outcomes: outcomes.map(&:to_s)
        ).call

        if result[:status] == :error
          render_error(message: result[:message], code: 'VALIDATION_ERROR', status: :unprocessable_entity)
        else
          render_success({
                           status: result[:status],
                           report: serialize_report(result[:report]),
                           message: status_message(result[:status])
                         })
        end
      end

      private

      def set_authorized_scrim
        @scrim = current_organization.scrims.find_by(id: params[:scrim_id])
        render_error(message: 'Scrim not found', code: 'NOT_FOUND', status: :not_found) unless @scrim
      end

      def set_scrim_request
        return unless @scrim

        @scrim_request = ScrimRequest.find_by(id: @scrim.scrim_request_id)
      end

      def opponent_organization
        return nil unless @scrim_request

        opp_id = if @scrim_request.requesting_organization_id == current_organization.id
                   @scrim_request.target_organization_id
                 else
                   @scrim_request.requesting_organization_id
                 end
        Organization.find_by(id: opp_id)
      end

      def report_for(org)
        return nil unless @scrim_request && org

        ScrimResultReport.find_by(scrim_request: @scrim_request, organization: org)
      end

      def combined_status(my, opponent)
        return 'no_request'     unless @scrim_request
        return 'pending'        unless my
        return my.status        if %w[confirmed unresolvable expired].include?(my.status)
        return 'waiting_opponent' if my.status == 'reported' && (!opponent || opponent.status == 'pending')

        my.status
      end

      def serialize_report(report)
        return nil unless report

        {
          id: report.id,
          status: report.status,
          game_outcomes: report.game_outcomes,
          reported_at: report.reported_at&.iso8601,
          confirmed_at: report.confirmed_at&.iso8601,
          deadline_at: report.deadline_at&.iso8601,
          attempt_count: report.attempt_count,
          attempts_remaining: report.attempts_remaining
        }
      end

      # Only exposes confirmation status to avoid leaking opponent's reported outcomes
      # before both sides have submitted (prevents copying the opponent's report).
      def serialize_opponent_report(report)
        return nil unless report

        exposable = %w[confirmed unresolvable expired]
        {
          status: report.status,
          has_reported: report.reported_at?,
          confirmed_at: report.confirmed_at&.iso8601,
          # Only expose outcomes once both have reported (no oracle attack)
          game_outcomes: exposable.include?(report.status) ? report.game_outcomes : nil
        }
      end

      def status_message(status)
        {
          reported: 'Result submitted. Waiting for opponent to report.',
          confirmed: 'Results match! Series result confirmed.',
          disputed: 'Results conflict with opponent\'s report. Both teams must re-report. ' \
                    "#{ScrimResultReport::MAX_ATTEMPTS} attempts total.",
          unresolvable: 'Maximum attempts reached with conflicting reports. Result marked unresolvable.'
        }[status] || 'Report received.'
      end
    end
  end
end
