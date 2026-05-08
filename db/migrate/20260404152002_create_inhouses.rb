# frozen_string_literal: true

class CreateInhouses < ActiveRecord::Migration[7.2]
  def change
    create_table :inhouses, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :status, default: 'waiting', null: false
      t.uuid :created_by_user_id, null: false
      t.integer :games_played, default: 0, null: false
      t.integer :blue_wins, default: 0, null: false
      t.integer :red_wins, default: 0, null: false

      t.timestamps
    end

    add_foreign_key :inhouses, :users, column: :created_by_user_id

    create_table :inhouse_participations, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :inhouse, null: false, foreign_key: true, type: :uuid
      t.references :player, null: false, foreign_key: true, type: :uuid
      t.string :team, default: 'none', null: false
      t.string :tier_snapshot

      t.timestamps
    end

    add_index :inhouse_participations, %i[inhouse_id player_id], unique: true
  end
end
