# frozen_string_literal: true

class DropRosterMemberships < ActiveRecord::Migration[7.2]
  def change
    drop_table :roster_memberships do |t|
      t.uuid   :organization_id, null: false
      t.uuid   :player_id,       null: false
      t.string :role,            null: false
      t.string :status,          null: false
      t.string :line,            default: 'main'
      t.uuid   :contract_id
      t.date   :joined_at,       null: false
      t.date   :left_at
      t.uuid   :created_by_id
      t.datetime :created_at,   null: false
      t.datetime :updated_at,   null: false
      t.datetime :deleted_at
    end
  end
end
