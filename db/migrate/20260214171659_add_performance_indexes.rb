# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # Index for matches COUNT query (26,444 calls, 8.9s total)
    # Query: SELECT COUNT(*) FROM matches WHERE organization_id = ? AND created_at > ?
    add_index :matches, %i[organization_id created_at],
              name: 'idx_matches_org_created',
              algorithm: :concurrently,
              if_not_exists: true

    # Additional helpful index for matches ordering
    add_index :matches, %i[organization_id id],
              name: 'idx_matches_org_id',
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :matches, name: 'idx_matches_org_created', if_exists: true
    remove_index :matches, name: 'idx_matches_org_id', if_exists: true
  end
end
