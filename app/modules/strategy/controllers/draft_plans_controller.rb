# frozen_string_literal: true

module Api
  module V1
    module Strategy
      # Draft Plans Controller
      # Manages draft strategies and if-then scenarios for teams
      class DraftPlansController < Api::V1::BaseController
        before_action :set_draft_plan, only: %i[show update destroy analyze activate deactivate]

        # GET /api/v1/strategy/draft_plans
        def index
          plans = organization_scoped(DraftPlan).includes(:created_by, :updated_by)
          plans = apply_filters(plans)
          plans = apply_sorting(plans)

          result = paginate(plans)

          render_success({
                           draft_plans: Strategy::Serializers::DraftPlanSerializer.render_as_hash(result[:data]),
                           total: result[:pagination][:total_count],
                           page: result[:pagination][:current_page],
                           per_page: result[:pagination][:per_page],
                           total_pages: result[:pagination][:total_pages]
                         })
        end

        # GET /api/v1/strategy/draft_plans/:id
        def show
          render_success({
                           draft_plan: Strategy::Serializers::DraftPlanSerializer.render_as_hash(@draft_plan)
                         })
        end

        # POST /api/v1/strategy/draft_plans
        def create
          plan = organization_scoped(DraftPlan).new(draft_plan_params)
          plan.organization = current_organization
          plan.created_by = current_user
          plan.updated_by = current_user

          if plan.save
            log_user_action(
              action: 'create',
              entity_type: 'DraftPlan',
              entity_id: plan.id,
              new_values: plan.attributes
            )

            render_created({
                             draft_plan: Strategy::Serializers::DraftPlanSerializer.render_as_hash(plan)
                           }, message: 'Draft plan created successfully')
          else
            render_error(
              message: 'Failed to create draft plan',
              code: 'VALIDATION_ERROR',
              status: :unprocessable_entity,
              details: plan.errors.as_json
            )
          end
        end

        # PATCH /api/v1/strategy/draft_plans/:id
        def update
          old_values = @draft_plan.attributes.dup
          @draft_plan.updated_by = current_user

          if @draft_plan.update(draft_plan_params)
            log_user_action(
              action: 'update',
              entity_type: 'DraftPlan',
              entity_id: @draft_plan.id,
              old_values: old_values,
              new_values: @draft_plan.attributes
            )

            render_updated({
                             draft_plan: Strategy::Serializers::DraftPlanSerializer.render_as_hash(@draft_plan)
                           })
          else
            render_error(
              message: 'Failed to update draft plan',
              code: 'VALIDATION_ERROR',
              status: :unprocessable_entity,
              details: @draft_plan.errors.as_json
            )
          end
        end

        # DELETE /api/v1/strategy/draft_plans/:id
        def destroy
          if @draft_plan.destroy
            log_user_action(
              action: 'delete',
              entity_type: 'DraftPlan',
              entity_id: @draft_plan.id,
              old_values: @draft_plan.attributes
            )

            render_deleted(message: 'Draft plan deleted successfully')
          else
            render_error(
              message: 'Failed to delete draft plan',
              code: 'DELETE_ERROR',
              status: :unprocessable_entity
            )
          end
        end

        # POST /api/v1/strategy/draft_plans/:id/analyze
        def analyze
          analysis = @draft_plan.analyze

          render_success({
                           draft_plan_id: @draft_plan.id,
                           analysis: analysis,
                           opponent_comfort_picks: @draft_plan.opponent_comfort_picks
                         })
        end

        # PATCH /api/v1/strategy/draft_plans/:id/activate
        def activate
          if @draft_plan.activate!
            render_updated({
                             draft_plan: Strategy::Serializers::DraftPlanSerializer.render_as_hash(@draft_plan)
                           }, message: 'Draft plan activated')
          else
            render_error(
              message: 'Failed to activate draft plan',
              code: 'UPDATE_ERROR',
              status: :unprocessable_entity
            )
          end
        end

        # PATCH /api/v1/strategy/draft_plans/:id/deactivate
        def deactivate
          if @draft_plan.deactivate!
            render_updated({
                             draft_plan: Strategy::Serializers::DraftPlanSerializer.render_as_hash(@draft_plan)
                           }, message: 'Draft plan deactivated')
          else
            render_error(
              message: 'Failed to deactivate draft plan',
              code: 'UPDATE_ERROR',
              status: :unprocessable_entity
            )
          end
        end

        private

        def set_draft_plan
          @draft_plan = organization_scoped(DraftPlan).find(params[:id])
        end

        def apply_filters(plans)
          plans = plans.by_opponent(params[:opponent]) if params[:opponent].present?
          plans = plans.by_side(params[:side]) if params[:side].present?
          plans = plans.by_patch(params[:patch]) if params[:patch].present?
          plans = plans.active if params[:active] == 'true'
          plans = plans.inactive if params[:active] == 'false'
          plans
        end

        def apply_sorting(plans)
          sort_by = params[:sort_by] || 'created_at'
          sort_order = params[:sort_order]&.downcase == 'asc' ? :asc : :desc

          plans.order(sort_by => sort_order)
        end

        def draft_plan_params
          params.require(:draft_plan).permit(
            :opponent_team,
            :side,
            :patch_version,
            :notes,
            :is_active,
            our_bans: [],
            opponent_bans: [],
            priority_picks: {},
            if_then_scenarios: [
              :trigger,
              :action,
              :note
            ]
          )
        end
      end
    end
  end
end
