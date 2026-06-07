# frozen_string_literal: true

# Removes the contract cache columns from players.
# These fields were migrated to the contracts table (MigratePlayerContracts).
#
# WARNING: down restores the columns as empty. Any data that existed before
# this migration ran will NOT be restored. Run only after MigratePlayerContracts
# and after a manual backup of the players table.
class DropPlayerContractCache < ActiveRecord::Migration[7.1]
  def up
    remove_column :players, :salary
    remove_column :players, :contract_start_date
    remove_column :players, :contract_end_date
  end

  def down
    add_column :players, :salary,              :decimal, precision: 10, scale: 2
    add_column :players, :contract_start_date, :date
    add_column :players, :contract_end_date,   :date
  end
end
