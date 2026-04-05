# frozen_string_literal: true

class AddScrimsLolFieldsToScrims < ActiveRecord::Migration[7.1]
  def change
    add_column :scrims, :source, :string, default: 'internal' # internal / scrims_lol
    add_column :scrims, :scrim_request_id, :uuid
    add_index :scrims, :scrim_request_id
    add_index :scrims, :source
  end
end
