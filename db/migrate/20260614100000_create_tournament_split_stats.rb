# frozen_string_literal: true

class CreateTournamentSplitStats < ActiveRecord::Migration[7.2]
  def change
    create_table :tournament_team_stats do |t|
      t.string   :tournament_id, null: false # e.g. 'CBLOL/2026 Season/Split 1 Playoffs'
      t.string   :team_name,     null: false
      t.string   :league,        null: false
      t.integer  :year,          null: false
      t.jsonb    :data,          null: false, default: {}
      t.datetime :computed_at,   null: false
      t.timestamps
    end

    add_index :tournament_team_stats,
              %i[tournament_id team_name],
              unique: true,
              name: 'uq_tournament_team_stats'
    add_index :tournament_team_stats, :league
    add_index :tournament_team_stats, %i[league year]

    create_table :tournament_player_stats do |t|
      t.string   :tournament_id, null: false
      t.string   :player_name,   null: false
      t.string   :team_name
      t.string   :league,        null: false
      t.integer  :year,          null: false
      t.string   :position
      t.jsonb    :data,          null: false, default: {}
      t.datetime :computed_at,   null: false
      t.timestamps
    end

    add_index :tournament_player_stats,
              %i[tournament_id player_name],
              unique: true,
              name: 'uq_tournament_player_stats'
    add_index :tournament_player_stats, :league
    add_index :tournament_player_stats, %i[tournament_id team_name]
  end
end
