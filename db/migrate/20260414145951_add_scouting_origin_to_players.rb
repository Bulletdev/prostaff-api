# frozen_string_literal: true

# Preserves the link between a hired player and the ScoutingTarget they came from.
# Also stores a snapshot of the scouting data at the time of hiring so that even if
# the ScoutingTarget is later updated or the status changes, the coach can always see
# what data drove the hiring decision.
class AddScoutingOriginToPlayers < ActiveRecord::Migration[7.1]
  def change
    add_column :players, :scouted_from_id, :uuid, null: true
    add_column :players, :scouting_data_snapshot, :jsonb, null: false, default: {}

    add_index :players, :scouted_from_id
    add_foreign_key :players, :scouting_targets, column: :scouted_from_id, on_delete: :nullify
  end
end
