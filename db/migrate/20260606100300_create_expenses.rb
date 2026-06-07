# frozen_string_literal: true

class CreateExpenses < ActiveRecord::Migration[7.1]
  def change
    create_table :expenses, id: :uuid do |t|
      t.uuid :organization_id,      null: false
      t.uuid :budget_allocation_id
      t.uuid :created_by_id,        null: false
      t.uuid :approved_by_id
      t.uuid :player_id

      t.string  :category,       null: false
      t.string  :description,    null: false
      t.decimal :amount,         precision: 12, scale: 2, null: false
      t.string  :currency,       default: 'BRL'
      t.date    :expense_date,   null: false
      t.string  :status,         default: 'pending'
      t.string  :payment_method
      t.date    :paid_at
      t.string  :receipt_url
      t.text    :notes
      t.boolean :recurring,      default: false
      t.string  :recurrence_rule

      t.timestamps
    end

    add_foreign_key :expenses, :organizations, column: :organization_id,
                    name: 'fk_expenses_organization'
    add_foreign_key :expenses, :budget_allocations, column: :budget_allocation_id,
                    name: 'fk_expenses_budget_allocation'
    add_foreign_key :expenses, :users, column: :created_by_id,
                    name: 'fk_expenses_created_by'
    add_foreign_key :expenses, :users, column: :approved_by_id,
                    name: 'fk_expenses_approved_by'
    add_foreign_key :expenses, :players, column: :player_id,
                    name: 'fk_expenses_player'

    add_index :expenses, %i[organization_id category]
    add_index :expenses, %i[organization_id expense_date]
    add_index :expenses, %i[organization_id status]
    add_index :expenses, :budget_allocation_id
    add_index :expenses, %i[player_id category]
  end
end
