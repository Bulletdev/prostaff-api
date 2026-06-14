# frozen_string_literal: true

class CreateChampionPatchStats < ActiveRecord::Migration[7.1]
  def change
    create_table :champion_patch_stats, id: :uuid do |t|
      t.string  :champion_name,     null: false
      t.string  :league,            null: false
      t.string  :patch,             null: false
      t.string  :role
      t.integer :blue_bans,         null: false, default: 0
      t.integer :red_bans,          null: false, default: 0
      t.integer :blue_picks,        null: false, default: 0
      t.integer :red_picks,         null: false, default: 0
      t.integer :wins,              null: false, default: 0
      t.integer :games,             null: false, default: 0
      # Contextual: 3 pre-Season 7, 5 from Season 7+. NOT used in presence_rate denominator.
      t.integer :ban_count_per_team, null: false, default: 5
      # (blue_bans + red_bans + blue_picks + red_picks) / games; range [0, 2.0]
      t.float   :presence_rate
      # wins / (blue_picks + red_picks); range [0, 1]
      t.float   :win_rate
      # Global pick position 1.0 (1st pick) to 10.0 (10th pick)
      t.float   :avg_pick_order
      t.datetime :computed_at

      t.timestamps
    end

    add_index :champion_patch_stats, %i[champion_name league patch role],
              unique: true,
              name: 'uq_champion_patch_stats'
    add_index :champion_patch_stats, %i[league patch]
  end
end
