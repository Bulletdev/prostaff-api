# frozen_string_literal: true

class AddEnabledLinesToOrganizations < ActiveRecord::Migration[7.2]
  def change
    add_column :organizations, :enabled_lines, :string, array: true, default: ['main'], null: false
    add_index :organizations, :enabled_lines, using: :gin
  end
end
