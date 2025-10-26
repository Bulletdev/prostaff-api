class AddKickUrlToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :kick_url, :string
  end
end
