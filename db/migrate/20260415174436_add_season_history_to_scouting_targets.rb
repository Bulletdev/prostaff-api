# frozen_string_literal: true

class AddSeasonHistoryToScoutingTargets < ActiveRecord::Migration[7.2]
  def change
    add_column :scouting_targets, :season_history, :jsonb, default: []
  end
end
