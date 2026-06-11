# frozen_string_literal: true

module Manager
  # Query object for filtering and sorting Expense records.
  #
  # Accepts a pre-scoped ActiveRecord relation and applies filter params.
  # Supported params: category, status, player_id, from+to (date range),
  # budget_allocation_id, sort_by (expense_date|amount|category), sort_order (asc|desc).
  #
  # @example Usage in controller
  #   expenses = Manager::ExpenseQuery.new(
  #     organization_scoped(Expense).includes(:player, :created_by),
  #     params
  #   ).call
  class ExpenseQuery
    SORTABLE = %w[expense_date amount category].freeze

    def initialize(scope, params)
      @scope  = scope
      @params = params
    end

    def call
      apply_filters(@scope)
    end

    private

    def apply_filters(scope)
      scope = filter_by_category(scope)
      scope = filter_by_status(scope)
      scope = filter_by_player(scope)
      scope = filter_by_period(scope)
      scope = filter_by_budget(scope)
      sort(scope)
    end

    def filter_by_category(scope)
      return scope unless @params[:category].present?

      scope.by_category(@params[:category])
    end

    def filter_by_status(scope)
      return scope unless @params[:status].present?

      scope.where(status: @params[:status])
    end

    def filter_by_player(scope)
      return scope unless @params[:player_id].present?

      scope.where(player_id: @params[:player_id])
    end

    def filter_by_period(scope)
      return scope unless @params[:from].present? && @params[:to].present?

      scope.by_period(@params[:from].to_date, @params[:to].to_date)
    end

    def filter_by_budget(scope)
      return scope unless @params[:budget_allocation_id].present?

      scope.where(budget_allocation_id: @params[:budget_allocation_id])
    end

    def sort(scope)
      column = SORTABLE.include?(@params[:sort_by]) ? @params[:sort_by] : 'expense_date'
      order  = @params[:sort_order] == 'desc' ? :desc : :asc
      scope.order(column => order)
    end
  end
end
