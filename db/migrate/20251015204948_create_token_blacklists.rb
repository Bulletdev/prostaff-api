class CreateTokenBlacklists < ActiveRecord::Migration[7.2]
  def change
    create_table :token_blacklists, id: :uuid do |t|
      t.string :jti, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :token_blacklists, :jti, unique: true
    add_index :token_blacklists, :expires_at
  end
end
