# frozen_string_literal: true

class AddFocusAreaToAvailabilityWindows < ActiveRecord::Migration[7.2]
  def change
    add_column :availability_windows, :focus_area, :string
  end
end
