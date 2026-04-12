# frozen_string_literal: true

class CreateMatchReports < ActiveRecord::Migration[7.2]
  def change
    create_table :match_reports, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :tournament_match, null: false, foreign_key: true, type: :uuid
      t.references :tournament_team,  null: false, foreign_key: true, type: :uuid
      t.references :reported_by_user, foreign_key: { to_table: :users }, type: :uuid

      # Reported scores (from perspective of this team's captain)
      t.integer :team_a_score, null: false, default: 0
      t.integer :team_b_score, null: false, default: 0

      # Evidence screenshot URL (required for report submission)
      t.string :evidence_url

      # pending | submitted | confirmed | disputed
      t.string :status, null: false, default: "pending"

      t.datetime :submitted_at
      t.datetime :confirmed_at
      t.datetime :deadline_at, null: false

      t.timestamps
    end

    add_index :match_reports, %i[tournament_match_id tournament_team_id], unique: true,
              name: "idx_match_reports_unique_per_team"
    add_index :match_reports, :status
  end
end
