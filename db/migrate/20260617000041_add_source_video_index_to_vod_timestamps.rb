# frozen_string_literal: true

class AddSourceVideoIndexToVodTimestamps < ActiveRecord::Migration[7.2]
  def change
    add_column :vod_timestamps, :source_video_index, :integer, default: 0
  end
end
