# frozen_string_literal: true

class CreateRosterMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :roster_memberships, id: :uuid do |t|
      t.uuid   :organization_id, null: false
      t.uuid   :player_id,       null: false
      t.string :role,            null: false
      t.string :status,          null: false
      t.string :line,            default: 'main'
      t.uuid   :contract_id
      t.date   :joined_at,       null: false
      t.date   :left_at
      t.uuid   :created_by_id
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :roster_memberships, %i[organization_id player_id left_at],
              name: 'idx_roster_memberships_active'
    add_index :roster_memberships, :contract_id
    add_index :roster_memberships, :deleted_at

    add_foreign_key :roster_memberships, :organizations
    add_foreign_key :roster_memberships, :players
    add_foreign_key :roster_memberships, :contracts, column: :contract_id
  end
end
