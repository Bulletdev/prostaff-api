class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :matches, [:organization_id, :victory], name: 'index_matches_on_org_and_victory'
    add_index :matches, [:organization_id, :game_start], name: 'index_matches_on_org_and_game_start'
    add_index :player_match_stats, :match_id, name: 'index_player_match_stats_on_match'
    add_index :schedules, [:organization_id, :start_time, :event_type], name: 'index_schedules_on_org_time_type'
    add_index :team_goals, [:organization_id, :status], name: 'index_team_goals_on_org_and_status'

    add_index :players, [:organization_id, :status], name: 'index_players_on_org_and_status'
    add_index :players, [:organization_id, :role], name: 'index_players_on_org_and_role'

    add_index :audit_logs, [:organization_id, :created_at], name: 'index_audit_logs_on_org_and_created'
  end
end
