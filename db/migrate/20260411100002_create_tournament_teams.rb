# frozen_string_literal: true

class CreateTournamentTeams < ActiveRecord::Migration[7.2]
  def change
    create_table :tournament_teams, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :tournament,   null: false, foreign_key: true, type: :uuid
      t.references :organization, null: false, foreign_key: true, type: :uuid

      # Team display info (snapshot at enrollment time)
      t.string :team_name, null: false
      t.string :team_tag,  null: false
      t.string :logo_url

      # pending | approved | rejected | withdrawn | disqualified
      t.string :status, null: false, default: "pending"

      t.integer :seed  # assigned during seeding phase
      t.string  :bracket_side  # upper | lower (current bracket position)

      t.datetime :enrolled_at,  null: false, default: -> { "NOW()" }
      t.datetime :approved_at
      t.datetime :rejected_at

      t.timestamps
    end

    add_index :tournament_teams, %i[tournament_id organization_id], unique: true,
              name: "idx_tournament_teams_unique_per_org"
    add_index :tournament_teams, :status
  end
end
