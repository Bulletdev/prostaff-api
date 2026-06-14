# frozen_string_literal: true

class CreateRosterSeasonSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :roster_season_snapshots, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string     :season,       null: false, comment: "e.g. '2026 Split 1' or 'CBLOL 2026 Split 1'"
      t.date       :snapshot_date, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid

      t.timestamps
    end

    add_index :roster_season_snapshots, %i[organization_id season],
              name: 'idx_roster_snapshots_org_season'

    create_table :roster_season_slots, id: :uuid do |t|
      t.references :roster_season_snapshot, null: false,
                                            foreign_key: true, type: :uuid,
                                            index: { name: 'idx_roster_slots_snapshot' }
      t.references :player, null: false, foreign_key: true, type: :uuid,
                            index: { name: 'idx_roster_slots_player' }
      t.string     :role,            comment: 'Lane role at the time of the snapshot'
      t.string     :line,            null: false, default: 'main',
                                     comment: 'main | academy | reserve | two_way'
      t.string     :transfer_status, comment: 'Optional: joined | departed | loan'

      t.timestamps
    end
  end
end
