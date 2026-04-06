# frozen_string_literal: true

class CreateScrimResultReports < ActiveRecord::Migration[7.2]
  def change
    create_table :scrim_result_reports, id: :uuid do |t|
      t.references :scrim_request, null: false, foreign_key: true, type: :uuid
      t.references :organization, null: false, foreign_key: true, type: :uuid

      # e.g. ["win","loss","win"] — one entry per game played
      t.string :game_outcomes, array: true, default: []

      # pending → waiting for this org to report
      # reported → this org reported, waiting for opponent
      # confirmed → both reports match
      # disputed → reports conflict
      # unresolvable → max attempts exceeded with conflict
      # expired → deadline passed without report
      t.string :status, null: false, default: 'pending'

      t.integer :attempt_count, null: false, default: 0
      t.datetime :reported_at
      t.datetime :deadline_at, null: false
      t.datetime :confirmed_at

      t.timestamps
    end

    add_index :scrim_result_reports,
              %i[scrim_request_id organization_id],
              unique: true,
              name: 'idx_scrim_result_reports_unique_per_org'
  end
end
