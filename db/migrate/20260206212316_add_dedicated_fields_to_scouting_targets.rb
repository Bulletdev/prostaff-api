class AddDedicatedFieldsToScoutingTargets < ActiveRecord::Migration[7.2]
  def change
    add_column :scouting_targets, :real_name, :string
    add_column :scouting_targets, :avatar_url, :string
    add_column :scouting_targets, :profile_icon_id, :integer
    add_column :scouting_targets, :peak_tier, :string
    add_column :scouting_targets, :peak_rank, :string
    add_column :scouting_targets, :last_api_sync_at, :datetime
  end
end
