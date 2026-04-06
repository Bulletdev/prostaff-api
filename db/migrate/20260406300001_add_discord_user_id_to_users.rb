# frozen_string_literal: true

class AddDiscordUserIdToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :discord_user_id, :string
    add_index  :users, :discord_user_id, unique: true, where: 'discord_user_id IS NOT NULL'
  end
end
