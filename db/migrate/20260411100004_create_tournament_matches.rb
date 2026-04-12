# frozen_string_literal: true

class CreateTournamentMatches < ActiveRecord::Migration[7.2]
  def change
    create_table :tournament_matches, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :tournament, null: false, foreign_key: true, type: :uuid

      # Self-referential FKs for O(1) bracket progression (no hardcoded round maps)
      t.uuid :next_match_winner_id  # winner advances here
      t.uuid :next_match_loser_id   # loser drops to here (nil for LB final / GF)

      # Competing teams (nil until bracket fills in)
      t.references :team_a, foreign_key: { to_table: :tournament_teams }, type: :uuid
      t.references :team_b, foreign_key: { to_table: :tournament_teams }, type: :uuid

      # Current scores (updated as reports come in)
      t.integer :team_a_score, null: false, default: 0
      t.integer :team_b_score, null: false, default: 0

      # Match outcome
      t.references :winner, foreign_key: { to_table: :tournament_teams }, type: :uuid
      t.references :loser,  foreign_key: { to_table: :tournament_teams }, type: :uuid

      # Bracket metadata
      t.string  :bracket_side,  null: false  # upper | lower | grand_final
      t.string  :round_label,   null: false  # "UB Round 1", "LB Final", "Grand Final"
      t.integer :round_order,   null: false  # sort order within phase
      t.integer :match_number,  null: false  # display number
      t.integer :bo_format,     null: false, default: 3

      # Status state machine
      # scheduled → checkin_open → in_progress → awaiting_report →
      # awaiting_confirm → confirmed → completed
      # disputed (from awaiting_confirm) → confirmed (admin resolves)
      # walkover (if team no-shows checkin)
      t.string :status, null: false, default: "scheduled"

      t.datetime :scheduled_at
      t.datetime :checkin_opens_at
      t.datetime :checkin_deadline_at
      t.datetime :wo_deadline_at
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :tournament_matches, :status
    add_index :tournament_matches, :next_match_winner_id
    add_index :tournament_matches, :next_match_loser_id
  end
end
