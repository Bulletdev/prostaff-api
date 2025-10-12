class AddSyncStatusToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :sync_status, :string
  end
end
