# frozen_string_literal: true

class AddLineToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :line, :string, default: 'main', null: false

    add_index :players, :line
  end
end
