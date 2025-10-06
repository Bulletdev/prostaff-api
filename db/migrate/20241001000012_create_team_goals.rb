class CreateTeamGoals < ActiveRecord::Migration[7.1]
  def change
    create_table :team_goals, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :player, foreign_key: true, type: :uuid

      # Goal Info
      t.string :title, null: false
      t.text :description
      t.string :category
      t.string :metric_type

      # Targets
      t.decimal :target_value, precision: 10, scale: 2
      t.decimal :current_value, precision: 10, scale: 2

      # Timeline
      t.date :start_date, null: false
      t.date :end_date, null: false

      # Status
      t.string :status, default: 'active'
      t.integer :progress, default: 0

      # Assignment
      t.references :assigned_to, foreign_key: { to_table: :users }, type: :uuid
      t.references :created_by, foreign_key: { to_table: :users }, type: :uuid

      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :team_goals, :status
    add_index :team_goals, :category
  end
end