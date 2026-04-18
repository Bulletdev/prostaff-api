# frozen_string_literal: true

class AddSourceAppToUsersAndPlayers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :source_app, :string, null: false, default: 'prostaff'
    add_column :players, :source_app, :string, null: false, default: 'arena_br'

    # password_reset_tokens: tornar user_id opcional e adicionar player_id
    # para suportar reset de senha de jogadores ArenaBR
    change_column_null :password_reset_tokens, :user_id, true
    add_column :password_reset_tokens, :player_id, :uuid

    add_index :users, :source_app
    add_index :players, :source_app
    add_index :password_reset_tokens, :player_id

    add_foreign_key :password_reset_tokens, :players, on_delete: :cascade

    # Garante que o token pertence a exatamente um sujeito
    execute <<-SQL
      ALTER TABLE password_reset_tokens
        ADD CONSTRAINT chk_token_owner
        CHECK (
          (user_id IS NOT NULL AND player_id IS NULL) OR
          (user_id IS NULL AND player_id IS NOT NULL)
        );
    SQL
  end

  def down
    execute "ALTER TABLE password_reset_tokens DROP CONSTRAINT IF EXISTS chk_token_owner;"
    remove_foreign_key :password_reset_tokens, :players
    remove_index :password_reset_tokens, :player_id
    remove_column :password_reset_tokens, :player_id
    change_column_null :password_reset_tokens, :user_id, false
    remove_index :players, :source_app
    remove_index :users, :source_app
    remove_column :players, :source_app
    remove_column :users, :source_app
  end
end
