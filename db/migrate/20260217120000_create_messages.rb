# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages, id: :uuid do |t|
      # sender
      t.references :user,         null: false, foreign_key: true, type: :uuid
      # recipient — null means group/broadcast; present means direct message
      t.references :recipient,    null: true,  foreign_key: { to_table: :users }, type: :uuid
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.text        :content,     null: false
      t.boolean     :deleted,     null: false, default: false
      t.datetime    :deleted_at

      t.timestamps
    end

    # DM history: load conversation between two users in the same org
    add_index :messages, %i[organization_id user_id recipient_id created_at],
              name: 'idx_messages_dm_created_at'

    # Reverse direction (so user B can query the same convo)
    add_index :messages, %i[organization_id recipient_id user_id created_at],
              name: 'idx_messages_dm_reverse'

    # Partial: only active (non-deleted) DMs
    add_index :messages, %i[organization_id user_id recipient_id created_at],
              where: 'deleted = false',
              name: 'idx_messages_active_dm'
  end
end
