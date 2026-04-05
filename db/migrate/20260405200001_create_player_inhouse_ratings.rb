# frozen_string_literal: true

class CreatePlayerInhouseRatings < ActiveRecord::Migration[7.2]
  def change
    create_table :player_inhouse_ratings, id: :uuid do |t|
      t.references :player,       null: false, foreign_key: true, type: :uuid
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string  :role,         null: false
      t.float   :mu,           null: false, default: 25.0
      t.float   :sigma,        null: false, default: 8.333333333333334
      t.integer :games_played, null: false, default: 0
      t.integer :wins,         null: false, default: 0
      t.integer :losses,       null: false, default: 0
      t.timestamps
    end

    add_index :player_inhouse_ratings, %i[player_id role], unique: true
    add_index :player_inhouse_ratings, %i[organization_id role]
  end
end
