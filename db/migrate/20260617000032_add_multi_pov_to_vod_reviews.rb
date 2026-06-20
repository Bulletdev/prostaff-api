# frozen_string_literal: true

class AddMultiPovToVodReviews < ActiveRecord::Migration[7.2]
  def change
    add_column :vod_reviews, :video_urls,         :string,  array: true, default: []
    add_column :vod_reviews, :video_sync_offsets, :integer, array: true, default: []
    add_column :vod_reviews, :video_labels,       :string,  array: true, default: []

    # Backward compatibility: preserve existing single video_url as first element
    execute <<~SQL
      UPDATE vod_reviews
      SET video_urls = ARRAY[video_url]
      WHERE video_url IS NOT NULL AND video_url != ''
    SQL
  end
end
