# frozen_string_literal: true

class CreateMlPredictionLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :ml_prediction_logs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string   :match_id
      t.jsonb    :blue_picks,         null: false, default: []
      t.jsonb    :red_picks,          null: false, default: []
      t.string   :patch
      t.string   :league
      t.decimal  :predicted_win_prob, precision: 5, scale: 4, null: false
      t.string   :model_version
      t.string   :source
      t.boolean  :blue_won
      t.timestamptz :predicted_at,    null: false, default: -> { "NOW()" }
      t.timestamptz :outcome_at

      t.timestamps
    end

    add_index :ml_prediction_logs, :predicted_at, order: { predicted_at: :desc }
    add_index :ml_prediction_logs, :match_id
  end
end
