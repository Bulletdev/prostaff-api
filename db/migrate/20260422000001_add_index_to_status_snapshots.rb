# frozen_string_literal: true

class AddIndexToStatusSnapshots < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :status_snapshots, %i[component checked_at],
              order: { checked_at: :desc },
              algorithm: :concurrently,
              if_not_exists: true,
              name: 'idx_status_snapshots_component_checked_at'
  end
end
