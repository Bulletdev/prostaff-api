# frozen_string_literal: true

module Manager
  module Controllers
    # Manages budget allocations for organizational financial planning.
    #
    # Budget allocations define the total available budget for a period.
    # Expenses are linked to allocations to compute burn rate.
    # All actions require owner, admin, or manager role.
    #
    # @example List all budgets
    #   GET /api/v1/manager/budgets
    #
    # @example Get financial summary for a budget period
    #   GET /api/v1/manager/budgets/:id/summary
    class BudgetsController < Api::V1::BaseController
      before_action :require_manager_access!
      before_action -> { require_tier_feature!(:budget_tracker) }
      before_action :set_budget, only: %i[show update destroy summary]
      after_action  :verify_authorized

      # GET /api/v1/manager/budgets
      def index
        authorize BudgetAllocation, :index?, policy_class: Manager::BudgetAllocationPolicy
        budgets = organization_scoped(BudgetAllocation).order(start_date: :desc)
        render_success paginate(budgets)
      end

      # POST /api/v1/manager/budgets
      def create
        authorize BudgetAllocation, :create?, policy_class: Manager::BudgetAllocationPolicy
        budget = organization_scoped(BudgetAllocation).new(budget_params)
        budget.created_by = current_user
        budget.save!
        log_user_action(action: 'create', entity_type: 'BudgetAllocation', entity_id: budget.id)
        render_created({ budget: budget.as_json })
      end

      # GET /api/v1/manager/budgets/:id
      def show
        authorize @budget, policy_class: Manager::BudgetAllocationPolicy
        render_success({ budget: @budget.as_json })
      end

      # PATCH /api/v1/manager/budgets/:id
      def update
        authorize @budget, policy_class: Manager::BudgetAllocationPolicy
        @budget.update!(budget_params)
        log_user_action(action: 'update', entity_type: 'BudgetAllocation', entity_id: @budget.id)
        render_success({ budget: @budget.as_json })
      end

      # DELETE /api/v1/manager/budgets/:id
      def destroy
        authorize @budget, policy_class: Manager::BudgetAllocationPolicy
        @budget.destroy!
        log_user_action(action: 'destroy', entity_type: 'BudgetAllocation', entity_id: @budget.id)
        render_deleted(message: 'Budget deleted')
      end

      # GET /api/v1/manager/budgets/:id/summary
      def summary
        authorize @budget, :summary?, policy_class: Manager::BudgetAllocationPolicy
        service_params = { from: @budget.start_date.to_s, to: @budget.end_date.to_s }
        burn_rate = Manager::BurnRateService.new(current_organization, service_params).call

        render_success({
                         budget: @budget.as_json,
                         burn_rate: burn_rate,
                         remaining: @budget.total_budget - burn_rate[:total_spent]
                       })
      end

      private

      def set_budget
        @budget = organization_scoped(BudgetAllocation).find(params[:id])
      end

      def require_manager_access!
        require_role!('owner', 'admin', 'manager')
      end

      def budget_params
        params.require(:budget).permit(
          :name, :period_type, :start_date, :end_date,
          :total_budget, :currency, :lineup, :notes, :status
        )
      end
    end
  end
end
