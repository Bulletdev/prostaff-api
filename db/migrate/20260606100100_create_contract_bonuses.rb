# frozen_string_literal: true

class CreateContractBonuses < ActiveRecord::Migration[7.1]
  def change
    create_table :contract_bonuses, id: :uuid do |t|
      t.uuid :contract_id,     null: false
      t.uuid :organization_id, null: false

      t.string  :bonus_type, null: false
      t.string  :trigger,    null: false
      t.decimal :amount,     precision: 12, scale: 2, null: false
      t.string  :currency,   default: 'BRL'
      t.string  :status,     default: 'pending'
      t.date    :achieved_at
      t.date    :paid_at
      t.text    :notes

      t.timestamps
    end

    add_foreign_key :contract_bonuses, :contracts, column: :contract_id,
                    name: 'fk_contract_bonuses_contract'
    add_foreign_key :contract_bonuses, :organizations, column: :organization_id,
                    name: 'fk_contract_bonuses_organization'

    add_index :contract_bonuses, :contract_id
    add_index :contract_bonuses, %i[organization_id status]
  end
end
