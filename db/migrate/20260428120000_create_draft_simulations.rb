# frozen_string_literal: true

class CreateDraftSimulations < ActiveRecord::Migration[7.2]
  def change
    create_table :draft_simulations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid   :organization_id, null: false
      t.string :series_id, null: false
      t.integer :game_number, null: false, default: 1
      t.string :patch
      t.string :league
      t.string :our_side
      t.string :team1_name
      t.string :team2_name
      t.boolean :fearless, default: false
      t.jsonb :blue_bans, default: []
      t.jsonb :red_bans, default: []
      t.jsonb :blue_picks, default: []
      t.jsonb :red_picks, default: []
      t.boolean :done, default: false
      t.jsonb :fearless_used, default: {}

      t.timestamps
    end

    add_foreign_key :draft_simulations, :organizations, on_delete: :cascade

    add_index :draft_simulations, :organization_id
    add_index :draft_simulations, :series_id
    add_index :draft_simulations, %i[organization_id series_id game_number], unique: true,
              name: 'index_draft_simulations_on_org_series_game'
  end
end
