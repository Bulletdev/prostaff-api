class AddOpponentTeamForeignKeyToScrims < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :scrims, :opponent_teams
  end
end
