# frozen_string_literal: true

class CreateGoalCheckIns < ActiveRecord::Migration[7.2]
  def change
    create_table :goal_check_ins, id: :uuid do |t|
      t.references :team_goal,    null: false, foreign_key: true, type: :uuid
      t.uuid       :organization_id, null: false
      t.decimal    :measured_value,  precision: 10, scale: 4
      t.text       :note
      t.string     :source,          null: false  # auto | manual
      t.uuid       :created_by_id
      t.timestamps
    end

    add_index :goal_check_ins, %i[team_goal_id created_at]
    add_index :goal_check_ins, :organization_id
  end
end
