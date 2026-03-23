# frozen_string_literal: true

class CreateFeedbackVotes < ActiveRecord::Migration[7.1]
  def change
    create_table :feedback_votes do |t|
      t.references :feedback, null: false, foreign_key: true
      t.references :user,     null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :feedback_votes, [:feedback_id, :user_id], unique: true

    add_column :feedbacks, :votes_count, :integer, null: false, default: 0
  end
end
