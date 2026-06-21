# frozen_string_literal: true

# Fixes the contract model so staff contracts can be created without a player.
#
# Before: player_id NOT NULL — forced every contract to have a player, making
# staff/coaching contracts impossible to model correctly.
#
# After: player_id optional, staff_member_id optional. Model validates that
# exactly one assignee is present for player/staff/coaching types.
class MakeContractAssigneePolymorphic < ActiveRecord::Migration[7.2]
  def up
    change_column_null :contracts, :player_id, true

    add_reference :contracts, :staff_member,
                  type: :uuid,
                  foreign_key: true,
                  null: true,
                  index: true
  end

  def down
    remove_reference :contracts, :staff_member

    # Only safe to restore NOT NULL if all rows have a player_id
    change_column_null :contracts, :player_id, false
  end
end
