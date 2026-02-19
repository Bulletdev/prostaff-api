# frozen_string_literal: true

# Analytics query optimisation — 5 composite indices that remove full-table scans
# on the hottest analytics endpoints (Performance, TeamComparison, Laning, Vision).
#
# All created CONCURRENTLY so they do not lock the table in production.
class AddAnalyticsPerformanceIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # best_performers / TeamComparison: GROUP BY player_id filtered by champion
    add_index :player_match_stats, %i[player_id champion],
              name: 'idx_pms_player_champion',
              algorithm: :concurrently,
              if_not_exists: true

    # best_performers / player individual stats: ORDER/filter by performance_score
    add_index :player_match_stats, %i[player_id performance_score],
              name: 'idx_pms_player_performance_score',
              algorithm: :concurrently,
              if_not_exists: true

    # Vision controller: AVG/ORDER on vision_score per player
    add_index :player_match_stats, %i[player_id vision_score],
              name: 'idx_pms_player_vision_score',
              algorithm: :concurrently,
              if_not_exists: true

    # Laning controller: AVG/ORDER on cs_per_min per player
    add_index :player_match_stats, %i[player_id cs_per_min],
              name: 'idx_pms_player_cs_per_min',
              algorithm: :concurrently,
              if_not_exists: true

    # Performance/TeamComparison: WHERE organization_id AND match_type filters on matches
    add_index :matches, %i[organization_id match_type],
              name: 'idx_matches_org_match_type',
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :player_match_stats, name: 'idx_pms_player_champion',          if_exists: true
    remove_index :player_match_stats, name: 'idx_pms_player_performance_score', if_exists: true
    remove_index :player_match_stats, name: 'idx_pms_player_vision_score',       if_exists: true
    remove_index :player_match_stats, name: 'idx_pms_player_cs_per_min',         if_exists: true
    remove_index :matches,            name: 'idx_matches_org_match_type',         if_exists: true
  end
end
