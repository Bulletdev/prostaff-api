# frozen_string_literal: true

class CreateContracts < ActiveRecord::Migration[7.1]
  def change
    create_table :contracts, id: :uuid do |t|
      t.uuid :organization_id, null: false
      t.uuid :player_id,       null: false
      t.uuid :created_by_id,   null: false
      t.uuid :updated_by_id

      t.string  :contract_type,         null: false
      t.string  :status,                null: false, default: 'draft'

      t.date    :start_date,            null: false
      t.date    :end_date,              null: false
      t.date    :signed_at
      t.date    :terminated_at

      t.decimal :base_salary,           precision: 12, scale: 2, null: false, default: 0
      t.string  :salary_currency,       null: false, default: 'BRL'
      t.string  :salary_period,         null: false, default: 'monthly'

      t.boolean :auto_renewal,          default: false
      t.integer :renewal_notice_days,   default: 30
      t.uuid    :renewed_from_id

      t.text    :notes
      t.jsonb   :metadata,              default: {}
      t.datetime :deleted_at

      t.timestamps
    end

    add_foreign_key :contracts, :organizations, column: :organization_id,
                    name: 'fk_contracts_organization'
    add_foreign_key :contracts, :players, column: :player_id,
                    name: 'fk_contracts_player'
    add_foreign_key :contracts, :users, column: :created_by_id,
                    name: 'fk_contracts_created_by'
    add_foreign_key :contracts, :users, column: :updated_by_id,
                    name: 'fk_contracts_updated_by'
    add_foreign_key :contracts, :contracts, column: :renewed_from_id,
                    name: 'fk_contracts_renewed_from'

    add_index :contracts, :organization_id
    add_index :contracts, :player_id
    add_index :contracts, %i[organization_id status]
    add_index :contracts, %i[organization_id end_date]
    add_index :contracts, %i[player_id status]
    add_index :contracts, %i[organization_id end_date status], name: 'idx_contracts_expiry_lookup'
    add_index :contracts, :renewed_from_id
  end
end
