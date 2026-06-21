# frozen_string_literal: true

require 'csv'

module Manager
  # Generates a UTF-8 CSV export of an Expense relation.
  #
  # Sanitizes text cells against CSV injection by prefixing values that start
  # with formula characters (=, +, -, @, TAB, CR) with a single quote.
  # Numeric fields (amount) are left as-is.
  #
  # @example
  #   csv = Manager::ExpenseCsvExporter.new(expenses).call
  #   send_data csv, filename: "expenses.csv", type: "text/csv"
  class ExpenseCsvExporter
    HEADERS = %w[
      id category description amount currency status
      expense_date payment_method player created_by approved_by notes
    ].freeze

    FORMULA_CHARS = /\A[=+\-@\t\r]/

    def initialize(expenses)
      @expenses = expenses
    end

    def call
      CSV.generate(headers: true, encoding: 'UTF-8') do |csv|
        csv << HEADERS
        @expenses.each { |e| csv << row(e) }
      end
    end

    private

    def row(expense)
      [
        expense.id,
        sanitize(expense.category),
        sanitize(expense.description),
        expense.amount,
        expense.currency,
        sanitize(expense.status),
        expense.expense_date&.iso8601,
        sanitize(expense.payment_method),
        sanitize(expense.player&.professional_name || expense.player&.summoner_name),
        sanitize(expense.created_by&.full_name),
        sanitize(expense.approved_by&.full_name),
        sanitize(expense.notes)
      ]
    end

    def sanitize(value)
      return value if value.nil?

      str = value.to_s
      str.match?(FORMULA_CHARS) ? "'#{str}" : str
    end
  end
end
