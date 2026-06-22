# frozen_string_literal: true

module TeamGoals
  module Controllers
    # REST API for manual GoalCheckIn creation and history retrieval.
    #
    # Auto check-ins are created by Goals::EvaluateGoalsJob; this controller
    # handles the manual (user-submitted) ones.
    #
    # Routes are nested under team_goals:
    #   GET  /api/v1/team-goals/:team_goal_id/check-ins
    #   POST /api/v1/team-goals/:team_goal_id/check-ins
    class GoalCheckInsController < Api::V1::BaseController
      before_action :set_team_goal
      before_action :set_check_in, only: :show

      # @return [JSON] paginated check-ins for the goal, chronological
      def index
        check_ins = @goal.goal_check_ins
                         .includes(:created_by)
                         .order(created_at: :desc)

        render_success({
                         check_ins: GoalCheckInSerializer.render_as_hash(check_ins),
                         total: check_ins.size
                       })
      end

      def show
        render_success({ check_in: GoalCheckInSerializer.render_as_hash(@check_in) })
      end

      # Creates a manual check-in and updates the goal's current_value cache.
      def create
        check_in = @goal.goal_check_ins.new(check_in_params)
        check_in.organization = current_organization
        check_in.created_by   = current_user
        check_in.source       = 'manual'

        authorize check_in, policy_class: GoalCheckInPolicy

        if check_in.save
          update_goal_current_value(check_in.measured_value)
          log_user_action(
            action: 'create',
            entity_type: 'GoalCheckIn',
            entity_id: check_in.id,
            new_values: check_in.attributes
          )
          render_created({ check_in: GoalCheckInSerializer.render_as_hash(check_in) },
                         message: 'Check-in recorded successfully')
        else
          render_error(
            message: 'Failed to create check-in',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: check_in.errors.as_json
          )
        end
      end

      private

      def set_team_goal
        @goal = organization_scoped(TeamGoal).find(params[:team_goal_id])
      end

      def set_check_in
        @check_in = @goal.goal_check_ins.find(params[:id])
      end

      def check_in_params
        params.require(:goal_check_in).permit(:measured_value, :note)
      end

      def update_goal_current_value(value)
        @goal.update_columns(current_value: value, updated_at: Time.current)
      rescue StandardError => e
        Rails.logger.warn(
          '[GoalCheckInsController] current_value cache update failed ' \
          "goal=#{@goal.id} error=#{e.message}"
        )
      end
    end
  end
end
