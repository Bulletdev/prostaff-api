class CreatePlayers < ActiveRecord::Migration[7.1]
  def change
    create_table :players, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :summoner_name, null: false
      t.string :real_name
      t.string :role, null: false
      t.string :country
      t.date :birth_date
      t.string :status, default: 'active'

      # Riot Games Data
      t.string :riot_puuid
      t.string :riot_summoner_id
      t.string :riot_account_id
      t.integer :profile_icon_id
      t.integer :summoner_level

      # Ranked Data
      t.string :solo_queue_tier
      t.string :solo_queue_rank
      t.integer :solo_queue_lp
      t.integer :solo_queue_wins
      t.integer :solo_queue_losses
      t.string :flex_queue_tier
      t.string :flex_queue_rank
      t.integer :flex_queue_lp
      t.string :peak_tier
      t.string :peak_rank
      t.string :peak_season

      # Contract Info
      t.date :contract_start_date
      t.date :contract_end_date
      t.decimal :salary, precision: 10, scale: 2
      t.integer :jersey_number

      # Additional Info
      t.text :champion_pool, array: true, default: []
      t.string :preferred_role_secondary
      t.text :playstyle_tags, array: true, default: []
      t.string :twitter_handle
      t.string :twitch_channel
      t.string :instagram_handle
      t.text :notes

      # Metadata
      t.jsonb :metadata, default: {}
      t.timestamp :last_sync_at

      t.timestamps
    end

    add_index :players, :riot_puuid, unique: true
    add_index :players, :summoner_name
    add_index :players, :status
    add_index :players, :role
  end
end