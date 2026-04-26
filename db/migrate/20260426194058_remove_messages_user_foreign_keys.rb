# frozen_string_literal: true

# Removes hard FK constraints that prevent player IDs being stored in
# messages.user_id (sender) and messages.recipient_id (target).
# After this migration those columns are free UUIDs — integrity is enforced
# at the application layer via recipient_type / sender_type.
class RemoveMessagesUserForeignKeys < ActiveRecord::Migration[7.2]
  def up
    remove_foreign_key :messages, name: 'fk_rails_12e9de2e48', if_exists: true # recipient_id -> users
    remove_foreign_key :messages, name: 'fk_rails_273a25a7a6', if_exists: true # user_id -> users
  end

  def down
    add_foreign_key :messages, :users, column: :user_id
    add_foreign_key :messages, :users, column: :recipient_id
  end
end
