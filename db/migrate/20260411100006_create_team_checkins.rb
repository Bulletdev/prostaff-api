# frozen_string_literal: true

class CreateTeamCheckins < ActiveRecord::Migration[7.2]
  def change
    create_table :team_checkins, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :tournament_match, null: false, foreign_key: true, type: :uuid
      t.references :tournament_team,  null: false, foreign_key: true, type: :uuid
      t.references :checked_in_by,    foreign_key: { to_table: :users }, type: :uuid

      t.datetime :checked_in_at, null: false, default: -> { "NOW()" }

      t.timestamps
    end

    add_index :team_checkins, %i[tournament_match_id tournament_team_id], unique: true,
              name: "idx_team_checkins_unique_per_team"
  end
end
