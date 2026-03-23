# frozen_string_literal: true

class RestoreMessagesRecipientId < ActiveRecord::Migration[7.2]
  def up
    # Restore recipient_id column if missing (DM feature requires it)
    unless column_exists?(:messages, :recipient_id)
      add_column :messages, :recipient_id, :uuid

      add_foreign_key :messages, :users, column: :recipient_id
    end

    # Restore DM indexes if missing
    unless index_exists?(:messages, %i[organization_id user_id recipient_id created_at],
                         name: 'idx_messages_dm_created_at')
      add_index :messages, %i[organization_id user_id recipient_id created_at],
                name: 'idx_messages_dm_created_at'
    end

    unless index_exists?(:messages, %i[organization_id recipient_id user_id created_at],
                         name: 'idx_messages_dm_reverse')
      add_index :messages, %i[organization_id recipient_id user_id created_at],
                name: 'idx_messages_dm_reverse'
    end

    unless index_exists?(:messages, %i[organization_id user_id recipient_id created_at],
                         name: 'idx_messages_active_dm')
      add_index :messages, %i[organization_id user_id recipient_id created_at],
                where: 'deleted = false',
                name: 'idx_messages_active_dm'
    end

    # Add recipient_id index for FK lookups
    return if index_exists?(:messages, :recipient_id)

    add_index :messages, :recipient_id
  end

  def down
    remove_index :messages, name: 'idx_messages_dm_created_at', if_exists: true
    remove_index :messages, name: 'idx_messages_dm_reverse', if_exists: true
    remove_index :messages, name: 'idx_messages_active_dm', if_exists: true
    remove_index :messages, :recipient_id, if_exists: true
    remove_foreign_key :messages, column: :recipient_id, if_exists: true
    remove_column :messages, :recipient_id, if_exists: true
  end
end
