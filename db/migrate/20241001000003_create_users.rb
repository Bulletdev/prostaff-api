class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :full_name
      t.string :role, null: false
      t.string :avatar_url
      t.string :timezone
      t.string :language
      t.boolean :notifications_enabled, default: true
      t.jsonb :notification_preferences, default: {}
      t.timestamp :last_login_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :role
  end
end