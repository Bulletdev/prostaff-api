# frozen_string_literal: true

# Adds a composite index on player_match_stats (player_id, champion, created_at)
# to accelerate champion pool analytics queries that filter by player and
# aggregate performance per champion over time.
#
# Uses CONCURRENTLY to avoid locking the table during migration.
# disable_ddl_transaction! is required when using algorithm: :concurrently.
class AddChampionPoolIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    unless index_exists?(:player_match_stats, %i[player_id champion created_at],
                          name: 'idx_pms_player_champion_date')
      add_index :player_match_stats, %i[player_id champion created_at],
                name: 'idx_pms_player_champion_date',
                algorithm: :concurrently
    end
  end
end
