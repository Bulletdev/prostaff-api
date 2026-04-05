class AddGamesAndDraftTypeToScrimRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :scrim_requests, :games_planned, :integer, default: 3
    add_column :scrim_requests, :draft_type, :string
  end
end
