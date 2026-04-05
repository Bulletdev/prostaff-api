# frozen_string_literal: true

class AddDraftTypeToScrimsAndAvailability < ActiveRecord::Migration[7.2]
  def change
    add_column :scrims, :draft_type, :string
    add_column :availability_windows, :draft_type, :string
  end
end
