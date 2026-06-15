class CreatePlayerRankSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :player_rank_snapshots, id: :uuid do |t|
      t.references :player, null: false, foreign_key: true, type: :uuid
      t.string  :queue_type,  null: false, default: "RANKED_SOLO_5x5",
                comment: "Riot queue type: RANKED_SOLO_5x5 | RANKED_FLEX_SR"
      t.string  :tier,        comment: "e.g. GRANDMASTER, CHALLENGER, MASTER"
      t.string  :rank,        comment: "e.g. I, II, III, IV (null for apex tiers)"
      t.integer :league_points, null: false, default: 0
      t.integer :wins,        null: false, default: 0
      t.integer :losses,      null: false, default: 0
      t.date    :recorded_on, null: false, comment: "Date the snapshot was taken (one per player per queue per day)"

      t.timestamps
    end

    add_index :player_rank_snapshots, [:player_id, :queue_type, :recorded_on],
              unique: true,
              name: "idx_player_rank_snapshots_unique"
    add_index :player_rank_snapshots, [:player_id, :recorded_on]
  end
end
