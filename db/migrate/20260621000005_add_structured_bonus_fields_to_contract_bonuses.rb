# frozen_string_literal: true

class AddStructuredBonusFieldsToContractBonuses < ActiveRecord::Migration[7.1]
  def change
    change_table :contract_bonuses, bulk: true do |t|
      t.string  :metric_key
      t.string  :comparator
      t.decimal :threshold, precision: 10, scale: 4
      t.string  :evaluation_window
      t.date    :window_start
      t.date    :window_end
    end

    add_index :contract_bonuses, :metric_key
    add_index :contract_bonuses, %i[evaluation_window window_start window_end],
              name: 'idx_contract_bonuses_window'
  end
end
