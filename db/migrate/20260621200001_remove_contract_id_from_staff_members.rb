# frozen_string_literal: true

# Removes the old staff_members.contract_id column.
#
# The contract→staff relationship is now managed via contracts.staff_member_id
# (added in MakeContractAssigneePolymorphic). Both FKs coexisting would diverge.
class RemoveContractIdFromStaffMembers < ActiveRecord::Migration[7.2]
  def change
    remove_reference :staff_members, :contract, foreign_key: true, null: true, type: :uuid
  end
end
