class AddAgeToScoutingTargets < ActiveRecord::Migration[7.2]
  def change
    add_column :scouting_targets, :age, :integer
  end
end
