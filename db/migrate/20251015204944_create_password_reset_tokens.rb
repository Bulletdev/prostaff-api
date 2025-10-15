class CreatePasswordResetTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :password_reset_tokens, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :token, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :password_reset_tokens, :token, unique: true
    add_index :password_reset_tokens, :expires_at
    add_index :password_reset_tokens, [:user_id, :used_at]
  end
end
