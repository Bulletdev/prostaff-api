# frozen_string_literal: true

class AddOeLookupIndexesToTournamentPlayerStats < ActiveRecord::Migration[7.2]
  def change
    add_column :tournament_player_stats, :raw_player_name, :string

    add_index :tournament_player_stats,
              'LOWER(player_name)',
              name: 'idx_tournament_player_stats_lower_player_name'

    add_index :tournament_player_stats,
              %i[year league position],
              name: 'idx_tournament_player_stats_discovery'
  end
end
