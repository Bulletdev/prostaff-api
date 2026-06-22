# frozen_string_literal: true

class CreateMarketRegistrations < ActiveRecord::Migration[7.1]
  def change
    create_table :market_registrations, id: :uuid do |t|
      t.string :player_external_name, null: false
      t.uuid   :scouting_target_id
      t.string :team_name
      t.string :region
      t.string :role
      t.string :residency
      t.date   :contract_end_date
      t.string :source, null: false, default: 'leaguepedia_gcd'
      t.string :source_url
      t.date   :snapshot_date, null: false
      t.jsonb  :raw_payload, default: {}
      t.timestamps
    end

    add_index :market_registrations, %i[player_external_name snapshot_date],
              unique: true, name: 'idx_market_reg_player_snapshot'
    add_index :market_registrations, %i[region contract_end_date]
    add_index :market_registrations, :scouting_target_id
    add_foreign_key :market_registrations, :scouting_targets, column: :scouting_target_id
  end
end
