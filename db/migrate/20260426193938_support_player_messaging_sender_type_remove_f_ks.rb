# frozen_string_literal: true

# Extends messages to support staff→player communication.
#
# Changes:
#   - Removes FK on recipient_id (was constrained to users, now can reference players)
#   - Removes FK on user_id (was constrained to users, now can reference players as senders)
#   - Adds sender_type column to distinguish User vs Player senders
#
# The recipient_type column was added in a previous migration (AddRecipientTypeToMessages).
class SupportPlayerMessagingSenderTypeRemoveFKs < ActiveRecord::Migration[7.2]
  def up
    remove_foreign_key :messages, column: :recipient_id, if_exists: true
    remove_foreign_key :messages, column: :user_id, if_exists: true

    add_column :messages, :sender_type, :string, default: 'User', null: false
  end

  def down
    remove_column :messages, :sender_type, if_exists: true

    add_foreign_key :messages, :users, column: :user_id
    add_foreign_key :messages, :users, column: :recipient_id
  end
end
