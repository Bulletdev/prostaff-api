class CreateDraftPlans < ActiveRecord::Migration[7.2]
  def change
    create_table :draft_plans do |t|
      t.uuid :organization_id, null: false
      t.string :opponent_team, null: false
      t.string :side, null: false # blue or red
      t.string :patch_version # e.g., '14.20'
      t.jsonb :our_bans, default: []
      t.jsonb :opponent_bans, default: []
      t.jsonb :priority_picks, default: {} # { role: champion }
      t.jsonb :if_then_scenarios, default: [] # Array of scenario objects
      t.text :notes
      t.boolean :is_active, default: true
      t.uuid :created_by_id, null: false
      t.uuid :updated_by_id, null: false

      t.timestamps
    end

    add_foreign_key :draft_plans, :organizations
    add_foreign_key :draft_plans, :users, column: :created_by_id
    add_foreign_key :draft_plans, :users, column: :updated_by_id

    add_index :draft_plans, :organization_id
    add_index :draft_plans, %i[organization_id opponent_team]
    add_index :draft_plans, %i[organization_id is_active]
    add_index :draft_plans, :patch_version
    add_index :draft_plans, :created_by_id
    add_index :draft_plans, :updated_by_id
  end
end
