# frozen_string_literal: true

class AddSoloQueueEnrichmentToMarketRegistrations < ActiveRecord::Migration[7.2]
  def change
    add_column :market_registrations, :solo_queue_server,      :string
    add_column :market_registrations, :solo_queue_id_override, :string
    add_column :market_registrations, :tag_enriched,           :boolean, null: false, default: false
  end
end
