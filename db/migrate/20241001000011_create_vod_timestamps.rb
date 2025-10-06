class CreateVodTimestamps < ActiveRecord::Migration[7.1]
  def change
    create_table :vod_timestamps, id: :uuid do |t|
      t.references :vod_review, null: false, foreign_key: true, type: :uuid

      # Timestamp Info
      t.integer :timestamp_seconds, null: false
      t.string :title, null: false
      t.text :description
      t.string :category
      t.string :importance, default: 'normal'

      # Target
      t.string :target_type
      t.references :target_player, foreign_key: { to_table: :players }, type: :uuid

      # Metadata
      t.references :created_by, foreign_key: { to_table: :users }, type: :uuid
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :vod_timestamps, :timestamp_seconds
    add_index :vod_timestamps, :category
    add_index :vod_timestamps, :importance
  end
end