class CreateScoutingTargets < ActiveRecord::Migration[7.1]
  def change
    create_table :scouting_targets, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid

      # Player Info
      t.string :summoner_name, null: false
      t.string :region, null: false
      t.string :riot_puuid
      t.string :role, null: false

      # Current Rank
      t.string :current_tier
      t.string :current_rank
      t.integer :current_lp

      # Performance
      t.text :champion_pool, array: true, default: []
      t.string :playstyle
      t.text :strengths, array: true, default: []
      t.text :weaknesses, array: true, default: []
      t.jsonb :recent_performance, default: {}
      t.string :performance_trend

      # Contact
      t.string :email
      t.string :phone
      t.string :discord_username
      t.string :twitter_handle

      # Scouting
      t.string :status, default: 'watching'
      t.string :priority, default: 'medium'
      t.references :added_by, foreign_key: { to_table: :users }, type: :uuid
      t.references :assigned_to, foreign_key: { to_table: :users }, type: :uuid
      t.timestamp :last_reviewed
      t.text :notes

      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :scouting_targets, :riot_puuid
    add_index :scouting_targets, :status
    add_index :scouting_targets, :priority
    add_index :scouting_targets, :role
  end
end