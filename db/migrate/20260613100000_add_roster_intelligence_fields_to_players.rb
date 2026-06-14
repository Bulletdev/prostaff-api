class AddRosterIntelligenceFieldsToPlayers < ActiveRecord::Migration[7.1]
  def change
    add_column :players, :residency, :string, comment: "Import slot classification: resident | non_resident | na_resident | americas_resident | native_resident. See Constants::Player::RESIDENCIES."
    add_column :players, :player_type, :string, default: "player", null: false, comment: "Record type: player | coach | analyst | manager"
    add_column :players, :staff_role, :string, comment: "Coaching staff function when player_type != player (e.g. head_coach, assistant_coach, analyst)"

    add_index :players, :residency
    add_index :players, :player_type
  end
end
