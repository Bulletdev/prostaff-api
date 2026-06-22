# frozen_string_literal: true

class CreateVodAnalysisJobs < ActiveRecord::Migration[7.2]
  def change
    create_table :vod_analysis_jobs, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.references :vod_review, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: 'pending'
      t.integer :progress, default: 0
      t.jsonb :suggested_timestamps, default: []
      t.string :external_job_id
      t.string :error_message
      t.timestamps
    end

    add_index :vod_analysis_jobs, :status
    # vod_review_id index is created automatically by t.references above
  end
end
