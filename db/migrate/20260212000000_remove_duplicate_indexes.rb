class RemoveDuplicateIndexes < ActiveRecord::Migration[7.2]
  def up
    # Remove duplicate indexes from matches table
    # Keep the shorter-named index (idx_*) and remove the longer Rails-generated ones
    remove_index :matches, name: "index_matches_on_org_and_game_start", if_exists: true
    remove_index :matches, name: "index_matches_on_org_and_victory", if_exists: true

    # Remove duplicate indexes from player_match_stats table
    # Keep the shortest name (idx_player_stats_match)
    remove_index :player_match_stats, name: "index_player_match_stats_on_match", if_exists: true
    remove_index :player_match_stats, name: "index_player_match_stats_on_match_id", if_exists: true

    # Remove duplicate indexes from players table
    remove_index :players, name: "index_players_on_org_and_status", if_exists: true

    # Remove duplicate indexes from schedules table
    remove_index :schedules, name: "index_schedules_on_org_time_type", if_exists: true

    # Remove duplicate indexes from team_goals table
    remove_index :team_goals, name: "index_team_goals_on_org_and_status", if_exists: true
  end

  def down
    # Re-create the removed indexes if rollback is needed
    add_index :matches, [:organization_id, :game_start], name: "index_matches_on_org_and_game_start", if_not_exists: true
    add_index :matches, [:organization_id, :victory], name: "index_matches_on_org_and_victory", if_not_exists: true

    add_index :player_match_stats, :match_id, name: "index_player_match_stats_on_match", if_not_exists: true
    add_index :player_match_stats, :match_id, name: "index_player_match_stats_on_match_id", if_not_exists: true

    add_index :players, [:organization_id, :status], name: "index_players_on_org_and_status", if_not_exists: true

    add_index :schedules, [:organization_id, :scheduled_time, :schedule_type], name: "index_schedules_on_org_time_type", if_not_exists: true

    add_index :team_goals, [:organization_id, :status], name: "index_team_goals_on_org_and_status", if_not_exists: true
  end
end
