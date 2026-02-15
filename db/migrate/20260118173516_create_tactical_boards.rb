class CreateTacticalBoards < ActiveRecord::Migration[7.2]
  def change
    create_table :tactical_boards do |t|
      t.uuid :organization_id, null: false
      t.uuid :match_id, null: true # Optional: can be linked to match
      t.uuid :scrim_id, null: true # Optional: can be linked to scrim
      t.string :title, null: false
      t.jsonb :map_state, default: {} # { players: [{ role, champion, x, y }] }
      t.jsonb :annotations, default: [] # [{ x, y, type, text, color }]
      t.string :game_time # e.g., "15:30" for timestamp
      t.uuid :created_by_id, null: false
      t.uuid :updated_by_id, null: false

      t.timestamps
    end

    add_foreign_key :tactical_boards, :organizations
    add_foreign_key :tactical_boards, :matches
    add_foreign_key :tactical_boards, :scrims
    add_foreign_key :tactical_boards, :users, column: :created_by_id
    add_foreign_key :tactical_boards, :users, column: :updated_by_id

    add_index :tactical_boards, :organization_id
    add_index :tactical_boards, %i[organization_id created_at]
    add_index :tactical_boards, :match_id
    add_index :tactical_boards, :scrim_id
    add_index :tactical_boards, :created_by_id
    add_index :tactical_boards, :updated_by_id
  end
end
