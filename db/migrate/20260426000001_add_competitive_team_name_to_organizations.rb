# frozen_string_literal: true

class AddCompetitiveTeamNameToOrganizations < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :competitive_team_name, :string, comment: "Competitive team name used to identify the org's matches in Leaguepedia (e.g. 'paiN Gaming')"
  end
end
