class AddAdvancedPerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    # Índices avançados que complementam os já existentes
    # Evitando duplicações com migration 20260203030000

    # 1. Índice parcial para players ativos (WHERE deleted_at IS NULL)
    # Complementa idx_players_org_deleted com filtro parcial
    add_index :players, %i[organization_id deleted_at],
      name: 'idx_players_org_deleted_active',
      where: "deleted_at IS NULL",
      if_not_exists: true,
      comment: 'Índice parcial para COUNT de players ativos'

    # 2. matches com game_start e victory (usado em analytics de winrate)
    add_index :matches, %i[organization_id game_start victory],
      name: 'idx_matches_org_game_start_victory',
      if_not_exists: true,
      comment: 'Otimiza queries de winrate por período'

    # 3. team_goals por status (dashboard de metas)
    add_index :team_goals, %i[organization_id status],
      name: 'idx_team_goals_org_status',
      if_not_exists: true,
      comment: 'Otimiza COUNT de goals por status'

    # 4. schedules com start_time e event_type (calendário)
    add_index :schedules, %i[organization_id start_time event_type],
      name: 'idx_schedules_org_time_type',
      if_not_exists: true,
      comment: 'Otimiza queries de próximos eventos'

    # 5. player_match_stats para agregações (SUM/AVG de estatísticas)
    # Complementa os índices existentes com ordem otimizada para aggregations
    add_index :player_match_stats, %i[match_id player_id],
      name: 'idx_player_stats_match_player_agg',
      if_not_exists: true,
      comment: 'Otimiza agregações de estatísticas (SUM kills/deaths/assists)'
  end
end
