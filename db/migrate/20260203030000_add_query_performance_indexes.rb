# frozen_string_literal: true

class AddQueryPerformanceIndexes < ActiveRecord::Migration[7.0]
  def change
    # Índices para otimizar queries de players com organization_id + deleted_at
    add_index :players, [:organization_id, :deleted_at],
              name: 'idx_players_org_deleted',
              if_not_exists: true

    # Índice composto para queries de players ativos por organização
    add_index :players, [:organization_id, :deleted_at, :status],
              name: 'idx_players_org_deleted_status',
              if_not_exists: true

    # Índices para sync_status
    add_index :players, [:organization_id, :sync_status],
              name: 'idx_players_org_sync_status',
              if_not_exists: true

    # Índice para last_sync_at (usado em verificações de sync)
    add_index :players, [:organization_id, :last_sync_at],
              name: 'idx_players_org_last_sync',
              if_not_exists: true

    # Índice para contract_end_date (usado em alertas de contrato)
    add_index :players, [:organization_id, :contract_end_date],
              name: 'idx_players_org_contract_end',
              if_not_exists: true

    # Índice para queries de matches por created_at (usado em tier_limits)
    add_index :matches, [:organization_id, :created_at],
              name: 'idx_matches_org_created',
              if_not_exists: true

    # Índice para schedules por event_type
    add_index :schedules, [:organization_id, :event_type],
              name: 'idx_schedules_org_event_type',
              if_not_exists: true
  end
end
