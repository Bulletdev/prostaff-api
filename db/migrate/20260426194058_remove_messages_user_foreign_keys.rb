# frozen_string_literal: true

# Removes hard FK constraints that prevent player IDs being stored in
# messages.user_id (sender) and messages.recipient_id (target).
# After this migration those columns are free UUIDs — integrity is enforced
# at the application layer via recipient_type / sender_type.
class RemoveMessagesUserForeignKeys < ActiveRecord::Migration[7.2]
  def up
    # no-op: FKs already removed by SupportPlayerMessagingSenderTypeRemoveFKs (20260426193938)
  end

  def down
    # no-op: reversing 20260426193938 restores the FKs
  end
end
