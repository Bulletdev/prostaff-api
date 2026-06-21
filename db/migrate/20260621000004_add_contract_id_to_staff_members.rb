# frozen_string_literal: true

class AddContractIdToStaffMembers < ActiveRecord::Migration[7.1]
  def change
    add_column :staff_members, :contract_id, :uuid
    add_index :staff_members, :contract_id
    add_foreign_key :staff_members, :contracts, column: :contract_id
  end
end
