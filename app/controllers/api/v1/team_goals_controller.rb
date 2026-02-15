# frozen_string_literal: true

module Api
  module V1
    class TeamGoalsController < Api::V1::BaseController
      before_action :set_team_goal, only: %i[show update destroy]

      def index
        goals = apply_goal_filters(organization_scoped(TeamGoal).includes(:player, :assigned_to, :created_by))
        goals = apply_goal_sorting(goals)
        result = paginate(goals)

        render_success({
                         goals: TeamGoalSerializer.render_as_hash(result[:data]),
                         pagination: result[:pagination],
                         summary: calculate_goals_summary(goals)
                       })
      end

      def show
        render_success({
                         goal: TeamGoalSerializer.render_as_hash(@goal)
                       })
      end

      def create
        goal = organization_scoped(TeamGoal).new(team_goal_params)
        goal.organization = current_organization
        goal.created_by = current_user

        if goal.save
          log_user_action(
            action: 'create',
            entity_type: 'TeamGoal',
            entity_id: goal.id,
            new_values: goal.attributes
          )

          render_created({
                           goal: TeamGoalSerializer.render_as_hash(goal)
                         }, message: 'Goal created successfully')
        else
          render_error(
            message: 'Failed to create goal',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: goal.errors.as_json
          )
        end
      end

      def update
        old_values = @goal.attributes.dup

        if @goal.update(team_goal_params)
          log_user_action(
            action: 'update',
            entity_type: 'TeamGoal',
            entity_id: @goal.id,
            old_values: old_values,
            new_values: @goal.attributes
          )

          render_updated({
                           goal: TeamGoalSerializer.render_as_hash(@goal)
                         })
        else
          render_error(
            message: 'Failed to update goal',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: @goal.errors.as_json
          )
        end
      end

      def destroy
        if @goal.destroy
          log_user_action(
            action: 'delete',
            entity_type: 'TeamGoal',
            entity_id: @goal.id,
            old_values: @goal.attributes
          )

          render_deleted(message: 'Goal deleted successfully')
        else
          render_error(
            message: 'Failed to delete goal',
            code: 'DELETE_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      private

      def set_team_goal
        @goal = organization_scoped(TeamGoal).find(params[:id])
      end

      def team_goal_params
        params.require(:team_goal).permit(
          :title, :description, :category, :metric_type,
          :target_value, :current_value, :start_date, :end_date,
          :status, :progress, :notes,
          :player_id, :assigned_to_id
        )
      end

      def apply_goal_filters(goals)
        goals = apply_basic_filters(goals)
        goals = apply_type_filters(goals)
        goals = apply_status_filters(goals)
        goals = goals.where(assigned_to_id: params[:assigned_to_id]) if params[:assigned_to_id].present?
        goals
      end

      def apply_basic_filters(goals)
        goals = goals.by_status(params[:status]) if params[:status].present?
        goals = goals.by_category(params[:category]) if params[:category].present?
        goals = goals.for_player(params[:player_id]) if params[:player_id].present?
        goals
      end

      def apply_type_filters(goals)
        goals = goals.team_goals if params[:type] == 'team'
        goals = goals.player_goals if params[:type] == 'player'
        goals
      end

      def apply_status_filters(goals)
        goals = goals.active if params[:active] == 'true'
        goals = goals.overdue if params[:overdue] == 'true'
        goals = goals.expiring_soon(params[:expiring_days]&.to_i || 7) if params[:expiring_soon] == 'true'
        goals
      end

      def apply_goal_sorting(goals)
        allowed_sort_fields = %w[created_at updated_at title status category start_date end_date progress]
        allowed_sort_orders = %w[asc desc]

        sort_by = allowed_sort_fields.include?(params[:sort_by]) ? params[:sort_by] : 'created_at'
        sort_order = allowed_sort_orders.include?(params[:sort_order]&.downcase) ? params[:sort_order].downcase : 'desc'
        goals.order(sort_by => sort_order)
      end

      def calculate_goals_summary(goals)
        {
          total: goals.count,
          by_status: goals.group(:status).count,
          by_category: goals.group(:category).count,
          active_count: goals.active.count,
          completed_count: goals.where(status: 'completed').count,
          overdue_count: goals.overdue.count,
          avg_progress: goals.active.average(:progress)&.round(1) || 0
        }
      end
    end
  end
end
