class CreateAvailabilityWindows < ActiveRecord::Migration[7.1]
  def change
    create_table :availability_windows, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.integer :day_of_week, null: false         # 0=Sun, 1=Mon, ..., 6=Sat
      t.integer :start_hour, null: false           # 0-23
      t.integer :end_hour, null: false             # 0-23
      t.string :timezone, null: false, default: 'UTC'
      t.string :game, null: false, default: 'league_of_legends'
      t.string :region                              # br, na, euw, etc
      t.string :tier_preference, default: 'any'   # any, same, adjacent
      t.boolean :active, null: false, default: true
      t.datetime :expires_at
      t.timestamps
    end

    # organization_id index já criado pelo t.references acima
    add_index :availability_windows, [:organization_id, :active]
    add_index :availability_windows, [:game, :region, :active]
    add_index :availability_windows, :day_of_week
  end
end
