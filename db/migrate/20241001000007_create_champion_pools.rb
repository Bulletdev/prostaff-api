class CreateChampionPools < ActiveRecord::Migration[7.1]
  def change
    create_table :champion_pools, id: :uuid do |t|
      t.references :player, null: false, foreign_key: true, type: :uuid
      t.string :champion, null: false

      # Performance
      t.integer :games_played, default: 0
      t.integer :games_won, default: 0
      t.integer :mastery_level, default: 1
      t.decimal :average_kda, precision: 5, scale: 2
      t.decimal :average_cs_per_min, precision: 5, scale: 2
      t.decimal :average_damage_share, precision: 5, scale: 2

      # Status
      t.boolean :is_comfort_pick, default: false
      t.boolean :is_pocket_pick, default: false
      t.boolean :is_learning, default: false
      t.integer :priority, default: 5

      # Metadata
      t.timestamp :last_played
      t.text :notes

      t.timestamps
    end

    add_index :champion_pools, [:player_id, :champion], unique: true
    add_index :champion_pools, :champion
    add_index :champion_pools, :priority
  end
end