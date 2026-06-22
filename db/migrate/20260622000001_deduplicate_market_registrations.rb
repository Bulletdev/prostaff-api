# frozen_string_literal: true

class DeduplicateMarketRegistrations < ActiveRecord::Migration[7.2]
  def up
    # Keep only the most recent snapshot per player, delete all older duplicates.
    execute <<~SQL
      DELETE FROM market_registrations
      WHERE id NOT IN (
        SELECT DISTINCT ON (player_external_name) id
        FROM market_registrations
        ORDER BY player_external_name, snapshot_date DESC, created_at DESC
      )
    SQL

    remove_index :market_registrations, name: 'idx_market_reg_player_snapshot'
    add_index :market_registrations, :player_external_name,
              unique: true, name: 'idx_market_reg_player_unique'
  end

  def down
    remove_index :market_registrations, name: 'idx_market_reg_player_unique'
    add_index :market_registrations, %i[player_external_name snapshot_date],
              unique: true, name: 'idx_market_reg_player_snapshot'
  end
end
