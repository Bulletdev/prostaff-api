# frozen_string_literal: true

class CreateStatusSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :status_snapshots, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string   :component,       null: false
      t.string   :status,          null: false
      t.integer  :response_time_ms
      t.datetime :checked_at, null: false

      t.timestamps
    end

    add_index :status_snapshots, %i[component checked_at]
  end
end
