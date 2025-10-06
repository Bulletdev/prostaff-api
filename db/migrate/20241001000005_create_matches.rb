class CreateMatches < ActiveRecord::Migration[7.1]
  def change
    create_table :matches, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :match_type, null: false
      t.string :riot_match_id

      # Game Info
      t.string :game_version
      t.timestamp :game_start
      t.timestamp :game_end
      t.integer :game_duration

      # Teams
      t.string :our_side
      t.string :opponent_name
      t.string :opponent_tag
      t.boolean :victory

      # Scores
      t.integer :our_score
      t.integer :opponent_score
      t.integer :our_towers
      t.integer :opponent_towers
      t.integer :our_dragons
      t.integer :opponent_dragons
      t.integer :our_barons
      t.integer :opponent_barons
      t.integer :our_inhibitors
      t.integer :opponent_inhibitors

      # Bans
      t.text :our_bans, array: true, default: []
      t.text :opponent_bans, array: true, default: []

      # Files
      t.string :vod_url
      t.string :replay_file_url

      # Organization
      t.text :tags, array: true, default: []
      t.text :notes
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :matches, :riot_match_id, unique: true
    add_index :matches, :match_type
    add_index :matches, :game_start
    add_index :matches, :victory
  end
end