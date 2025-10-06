class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true

      t.string :title, limit: 200, null: false
      t.text :message, null: false
      t.string :type, null: false

      # Linking
      t.text :link_url
      t.string :link_type, limit: 20
      t.uuid :link_id

      # Status
      t.boolean :is_read, default: false
      t.timestamp :read_at

      # Delivery channels
      t.text :channels, array: true, default: ['in_app']
      t.boolean :email_sent, default: false
      t.boolean :discord_sent, default: false

      t.jsonb :metadata, default: {}

      t.timestamps null: false
    end

    add_index :notifications, :user_id
    add_index :notifications, :is_read
    add_index :notifications, :created_at, order: { created_at: :desc }

    # Add check constraint for notification type
    execute <<-SQL
      ALTER TABLE notifications
      ADD CONSTRAINT notifications_type_check
      CHECK (type IN ('info', 'success', 'warning', 'error', 'match', 'schedule', 'system'));
    SQL
  end
end
