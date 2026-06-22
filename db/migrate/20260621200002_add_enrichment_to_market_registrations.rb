# frozen_string_literal: true

class AddEnrichmentToMarketRegistrations < ActiveRecord::Migration[7.2]
  def change
    add_column :market_registrations, :solo_queue_id, :string
    add_column :market_registrations, :image_url, :string
  end
end
