# frozen_string_literal: true

module Manager
  # Serializer for Expense model.
  class ExpenseSerializer < Blueprinter::Base
    identifier :id

    fields :category, :description, :amount, :currency, :expense_date,
           :status, :payment_method, :paid_at, :receipt_url, :notes,
           :recurring, :recurrence_rule, :created_at, :updated_at

    association :player, blueprint: PlayerSummarySerializer
  end
end
