# frozen_string_literal: true

class AddDrawingToVodTimestamps < ActiveRecord::Migration[7.1]
  def change
    add_column :vod_timestamps, :drawing_data, :jsonb, default: {}
    add_column :vod_timestamps, :annotations,  :jsonb, default: []
  end
end
