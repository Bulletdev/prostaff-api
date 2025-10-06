class CreateVodReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :vod_reviews, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :match, foreign_key: true, type: :uuid

      # Review Info
      t.string :title, null: false
      t.text :description
      t.string :review_type
      t.timestamp :review_date

      # Video
      t.string :video_url, null: false
      t.string :thumbnail_url
      t.integer :duration

      # Sharing
      t.boolean :is_public, default: false
      t.string :share_link
      t.uuid :shared_with_players, array: true, default: []

      # Organization
      t.references :reviewer, foreign_key: { to_table: :users }, type: :uuid
      t.string :status, default: 'draft'
      t.text :tags, array: true, default: []

      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :vod_reviews, :status
    add_index :vod_reviews, :share_link, unique: true
  end
end