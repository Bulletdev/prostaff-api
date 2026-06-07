# frozen_string_literal: true

class CreateBudgetAllocations < ActiveRecord::Migration[7.1]
  def change
    create_table :budget_allocations, id: :uuid do |t|
      t.uuid :organization_id, null: false
      t.uuid :created_by_id,   null: false

      t.string  :name,         null: false
      t.string  :period_type,  null: false
      t.date    :start_date,   null: false
      t.date    :end_date,     null: false
      t.decimal :total_budget, precision: 14, scale: 2, null: false
      t.string  :currency,     default: 'BRL'
      t.string  :lineup,       default: 'main'
      t.text    :notes
      t.string  :status,       default: 'active'

      t.timestamps
    end

    add_foreign_key :budget_allocations, :organizations, column: :organization_id,
                    name: 'fk_budget_allocs_organization'
    add_foreign_key :budget_allocations, :users, column: :created_by_id,
                    name: 'fk_budget_allocs_created_by'

    add_index :budget_allocations, %i[organization_id status]
    add_index :budget_allocations, %i[organization_id start_date end_date],
              name: 'idx_budget_allocs_period'
  end
end
