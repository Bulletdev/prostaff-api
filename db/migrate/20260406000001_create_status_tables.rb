# frozen_string_literal: true

class CreateStatusTables < ActiveRecord::Migration[7.2]
  def change
    create_table :status_incidents, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string   :title,               null: false
      t.text     :body,                null: false
      t.string   :severity,            null: false, default: 'minor'
      t.string   :status,              null: false, default: 'investigating'
      t.string   :affected_components, null: false, array: true, default: []
      t.datetime :started_at,          null: false
      t.datetime :resolved_at
      t.text     :postmortem
      t.uuid     :created_by_user_id

      t.timestamps
    end

    add_foreign_key :status_incidents, :users, column: :created_by_user_id

    add_index :status_incidents, :status
    add_index :status_incidents, :severity
    add_index :status_incidents, :started_at

    create_table :status_incident_updates, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :status_incident, null: false, foreign_key: true, type: :uuid
      t.string :status,              null: false
      t.text   :body,                null: false
      t.uuid   :created_by_user_id

      t.timestamps
    end

    add_foreign_key :status_incident_updates, :users, column: :created_by_user_id
  end
end
