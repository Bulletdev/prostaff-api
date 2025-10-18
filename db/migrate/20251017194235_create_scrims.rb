class CreateScrims < ActiveRecord::Migration[7.2]
  def change
    create_table :scrims, id: :uuid do |t|
      t.uuid :organization_id, null: false
      t.uuid :match_id
      t.uuid :opponent_team_id

      # Scrim metadata
      t.datetime :scheduled_at
      t.string :scrim_type # practice, vod_review, tournament_prep
      t.string :focus_area # draft, macro, teamfight, laning, etc
      t.text :pre_game_notes
      t.text :post_game_notes

      # Privacy & tracking
      t.boolean :is_confidential, default: true
      t.string :visibility # internal_only, coaching_staff, full_team

      # Results tracking
      t.integer :games_planned
      t.integer :games_completed
      t.jsonb :game_results, default: []

      # Performance goals
      t.jsonb :objectives, default: {} # What we wanted to practice
      t.jsonb :outcomes, default: {}   # What we achieved

      t.timestamps
    end

    add_index :scrims, :organization_id
    add_index :scrims, :opponent_team_id
    add_index :scrims, :match_id
    add_index :scrims, :scheduled_at
    add_index :scrims, [:organization_id, :scheduled_at], name: 'idx_scrims_org_scheduled'
    add_index :scrims, :scrim_type

    add_foreign_key :scrims, :organizations
    add_foreign_key :scrims, :matches
  end
end
