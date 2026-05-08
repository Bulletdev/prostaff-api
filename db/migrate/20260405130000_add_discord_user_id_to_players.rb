# frozen_string_literal: true

# Adds discord_user_id to players so the Discord bot can look up a player
# by their Discord account and perform actions (join queue, check stats) on
# their behalf using the org's coach token.
#
# The field is scoped to the player, not the guild — a player belongs to one
# org and has one Discord account. Uniqueness is enforced at the DB level.
class AddDiscordUserIdToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :discord_user_id, :string
    add_index  :players, :discord_user_id, unique: true, where: 'discord_user_id IS NOT NULL'
  end
end
