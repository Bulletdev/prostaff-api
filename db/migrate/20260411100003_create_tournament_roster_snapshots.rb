# frozen_string_literal: true

# Immutable roster snapshot created at approval time (Roster Lock).
# Records which players were on the team when inscription was approved.
# Used for dispute resolution and historical audit — never mutated after creation.
class CreateTournamentRosterSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :tournament_roster_snapshots, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :tournament_team, null: false, foreign_key: true, type: :uuid
      t.references :player,          null: false, foreign_key: true, type: :uuid

      # Snapshot fields — copied from player at lock time, immutable
      t.string  :summoner_name, null: false
      t.string  :role          # top | jungle | mid | adc | support
      t.string  :position,     null: false  # starter | substitute

      t.datetime :locked_at, null: false, default: -> { "NOW()" }

      t.timestamps
    end

    add_index :tournament_roster_snapshots, %i[tournament_team_id player_id], unique: true,
              name: "idx_roster_snapshots_unique_per_player"
  end
end
