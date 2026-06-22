# frozen_string_literal: true

# Creates the staff_members table for non-player team staff (coaches, analysts, etc.).
#
# This migration guards against double-execution: on Supabase the table may already
# exist (created before this migration was introduced). On fresh CI databases it
# won't exist yet, so we create it here to unblock subsequent migrations that
# reference it (add_contract_id, make_contract_assignee_polymorphic, etc.).
class CreateStaffMembers < ActiveRecord::Migration[7.2]
  def up
    return if connection.table_exists?(:staff_members)

    create_table :staff_members, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.uuid   :organization_id, null: false
      t.string :name,            null: false
      t.string :role,            null: false
      t.string :status,          null: false, default: 'active'
      t.string :line
      t.string :country,         limit: 2
      t.date   :birth_date
      t.date   :contract_start_date
      t.date   :contract_end_date
      t.string :twitter_handle
      t.string :instagram_handle
      t.string :avatar_url
      t.text   :notes
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :staff_members, :organization_id
    add_index :staff_members, :role
    add_index :staff_members, :status
    add_index :staff_members, :deleted_at

    add_foreign_key :staff_members, :organizations
  end

  def down
    drop_table :staff_members, if_exists: true
  end
end
