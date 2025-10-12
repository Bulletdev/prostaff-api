class AddRegionToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :region, :string
  end
end
