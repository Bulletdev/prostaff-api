# frozen_string_literal: true

module Manager
  # Computes the burn rate (spending breakdown) for an organization in a given period.
  #
  # Only paid expenses are counted in the burn rate. Pending expenses are reported
  # separately as a forward-looking liability indicator.
  #
  # @example
  #   Manager::BurnRateService.new(current_organization, from: '2026-01-01', to: '2026-01-31').call
  #   # => { period: {...}, total_spent: 50000.0, by_category: {...}, ... }
  class BurnRateService
    def initialize(organization, params = {})
      @org  = organization
      @from = params[:from]&.to_date || Date.current.beginning_of_month
      @to   = params[:to]&.to_date   || Date.current.end_of_month
    end

    def call
      paid_expenses = Expense.unscoped.where(organization: @org).by_period(@from, @to).paid
      by_category   = build_category_breakdown(paid_expenses)

      {
        period: { from: @from, to: @to },
        total_spent: paid_expenses.sum(:amount),
        by_category: by_category,
        salary_total: salary_total(by_category),
        operational: operational_total(by_category),
        pending_approval: Expense.unscoped.where(organization: @org).pending.sum(:amount)
      }
    end

    private

    def build_category_breakdown(expenses)
      Expense::CATEGORIES.index_with do |cat|
        expenses.by_category(cat).sum(:amount)
      end
    end

    def salary_total(by_category)
      by_category.fetch('salary', 0).to_d + by_category.fetch('bonus', 0).to_d
    end

    def operational_total(by_category)
      by_category.except('salary', 'bonus').values.sum(&:to_d)
    end
  end
end
