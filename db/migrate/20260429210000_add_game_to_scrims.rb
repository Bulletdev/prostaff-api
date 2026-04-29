# frozen_string_literal: true

class AddGameToScrims < ActiveRecord::Migration[7.1]
  def change
    add_column :scrims, :game, :string, null: false, default: 'league_of_legends'
    add_index :scrims, :game
    add_index :scrims, %i[game visibility scheduled_at], name: 'idx_scrims_game_visibility_scheduled'
  end
end
