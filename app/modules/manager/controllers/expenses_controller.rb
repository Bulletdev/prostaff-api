# frozen_string_literal: true

module Manager
  module Controllers
    # Manages financial expenses for an organization.
    #
    # Expenses are restricted to owner, admin, and manager roles — salary and
    # budget data must never reach coach, analyst, or viewer roles.
    #
    # Status flow: pending -> approved -> paid (or rejected at any pending stage).
    #
    # @example Approve a pending expense
    #   POST /api/v1/manager/expenses/:id/approve
    #
    # @example Get salary summary (payroll from active contracts)
    #   GET /api/v1/manager/expenses/salary_summary
    class ExpensesController < Api::V1::BaseController
      before_action :require_manager_access!
      before_action -> { require_tier_feature!(:contracts_basic) },
                    only: %i[index show create update destroy approve mark_paid reject]
      before_action -> { require_tier_feature!(:budget_tracker) },
                    only: %i[report salary_summary export]
      before_action :set_expense, only: %i[show update destroy approve mark_paid reject]
      after_action  :verify_authorized

      # GET /api/v1/manager/expenses
      def index
        authorize Expense, :index?, policy_class: Manager::ExpensePolicy
        expenses = Manager::ExpenseQuery.new(
          organization_scoped(Expense).includes(:player, :created_by, :approved_by),
          params
        ).call
        render_success paginate(expenses)
      end

      # GET /api/v1/manager/expenses/:id
      def show
        authorize @expense, policy_class: Manager::ExpensePolicy
        render_success(
          { expense: Manager::ExpenseSerializer.render_as_hash(@expense) }
        )
      end

      # POST /api/v1/manager/expenses
      def create
        authorize Expense, :create?, policy_class: Manager::ExpensePolicy
        expense = organization_scoped(Expense).new(expense_params)
        expense.created_by = current_user
        expense.save!
        log_user_action(action: 'create', entity_type: 'Expense', entity_id: expense.id)
        render_created(
          { expense: Manager::ExpenseSerializer.render_as_hash(expense) }
        )
      end

      # PATCH /api/v1/manager/expenses/:id
      def update
        authorize @expense, policy_class: Manager::ExpensePolicy
        @expense.update!(expense_params)
        log_user_action(action: 'update', entity_type: 'Expense', entity_id: @expense.id)
        render_success(
          { expense: Manager::ExpenseSerializer.render_as_hash(@expense) }
        )
      end

      # DELETE /api/v1/manager/expenses/:id
      def destroy
        authorize @expense, policy_class: Manager::ExpensePolicy
        @expense.destroy!
        log_user_action(action: 'destroy', entity_type: 'Expense', entity_id: @expense.id)
        render_deleted(message: 'Expense deleted')
      end

      # POST /api/v1/manager/expenses/:id/approve
      def approve
        authorize @expense, policy_class: Manager::ExpensePolicy
        @expense.update!(status: 'approved', approved_by: current_user)
        log_user_action(action: 'approve', entity_type: 'Expense', entity_id: @expense.id)
        render_success(
          { expense: Manager::ExpenseSerializer.render_as_hash(@expense) }
        )
      end

      # POST /api/v1/manager/expenses/:id/mark_paid
      def mark_paid
        authorize @expense, policy_class: Manager::ExpensePolicy
        @expense.update!(status: 'paid', paid_at: Date.current)
        log_user_action(action: 'mark_paid', entity_type: 'Expense', entity_id: @expense.id)
        render_success(
          { expense: Manager::ExpenseSerializer.render_as_hash(@expense) }
        )
      end

      # POST /api/v1/manager/expenses/:id/reject
      def reject
        authorize @expense, policy_class: Manager::ExpensePolicy
        @expense.update!(status: 'rejected')
        log_user_action(action: 'reject', entity_type: 'Expense', entity_id: @expense.id)
        render_success(
          { expense: Manager::ExpenseSerializer.render_as_hash(@expense) }
        )
      end

      # GET /api/v1/manager/expenses/salary_summary
      def salary_summary
        authorize Expense, :salary_summary?, policy_class: Manager::ExpensePolicy
        render_success Manager::SalarySummaryService.new(current_organization).call
      end

      # GET /api/v1/manager/expenses/report
      def report
        authorize Expense, :report?, policy_class: Manager::ExpensePolicy
        render_success Manager::BurnRateService.new(current_organization, report_params).call
      end

      # GET /api/v1/manager/expenses/export
      # Returns a CSV of expenses filtered by the same params as #index.
      # Cells beginning with formula characters are prefixed with ' to prevent
      # CSV injection in Excel/LibreOffice.
      def export
        authorize Expense, :export?, policy_class: Manager::ExpensePolicy
        expenses = Manager::ExpenseQuery.new(
          organization_scoped(Expense).includes(:player, :created_by, :approved_by),
          params
        ).call

        csv = Manager::ExpenseCsvExporter.new(expenses).call
        filename = "expenses_#{Date.current.iso8601}.csv"
        send_data csv, filename: filename, type: 'text/csv; charset=utf-8', disposition: 'attachment'
      end

      private

      def set_expense
        @expense = organization_scoped(Expense).find(params[:id])
      end

      def require_manager_access!
        require_role!('owner', 'admin', 'manager')
      end

      def expense_params
        params.require(:expense).permit(
          :budget_allocation_id, :player_id, :category, :description,
          :amount, :currency, :expense_date, :payment_method,
          :receipt_url, :recurring, :recurrence_rule, :notes
        )
      end

      def report_params
        params.permit(:from, :to, :category, :lineup)
      end
    end
  end
end
