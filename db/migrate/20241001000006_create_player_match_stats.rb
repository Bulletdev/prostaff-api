class CreatePlayerMatchStats < ActiveRecord::Migration[7.1]
  def change
    create_table :player_match_stats, id: :uuid do |t|
      t.references :match, null: false, foreign_key: true, type: :uuid
      t.references :player, null: false, foreign_key: true, type: :uuid

      # Champion & Position
      t.string :champion, null: false
      t.string :role
      t.string :lane

      # KDA
      t.integer :kills, default: 0
      t.integer :deaths, default: 0
      t.integer :assists, default: 0
      t.integer :double_kills, default: 0
      t.integer :triple_kills, default: 0
      t.integer :quadra_kills, default: 0
      t.integer :penta_kills, default: 0
      t.integer :largest_killing_spree
      t.integer :largest_multi_kill

      # Farm
      t.integer :cs, default: 0
      t.decimal :cs_per_min, precision: 5, scale: 2

      # Gold
      t.integer :gold_earned
      t.decimal :gold_per_min, precision: 8, scale: 2
      t.decimal :gold_share, precision: 5, scale: 2

      # Damage
      t.integer :damage_dealt_champions
      t.integer :damage_dealt_total
      t.integer :damage_dealt_objectives
      t.integer :damage_taken
      t.integer :damage_mitigated
      t.decimal :damage_share, precision: 5, scale: 2

      # Vision
      t.integer :vision_score
      t.integer :wards_placed
      t.integer :wards_destroyed
      t.integer :control_wards_purchased

      # Combat
      t.decimal :kill_participation, precision: 5, scale: 2
      t.boolean :first_blood, default: false
      t.boolean :first_tower, default: false

      # Build
      t.integer :items, array: true, default: []
      t.integer :item_build_order, array: true, default: []
      t.integer :trinket
      t.string :summoner_spell_1
      t.string :summoner_spell_2
      t.string :primary_rune_tree
      t.string :secondary_rune_tree
      t.integer :runes, array: true, default: []

      # Other
      t.integer :healing_done
      t.decimal :performance_score, precision: 5, scale: 2

      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :player_match_stats, [:player_id, :match_id], unique: true
    add_index :player_match_stats, :champion
  end
end