class AddTeamTagToOrganizations < ActiveRecord::Migration[7.2]
  def change
    add_column :organizations, :team_tag, :string, limit: 5
  end
end
