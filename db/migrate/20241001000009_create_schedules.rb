class CreateSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :schedules, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid

      # Event Info
      t.string :title, null: false
      t.text :description
      t.string :event_type, null: false

      # Time
      t.timestamp :start_time, null: false
      t.timestamp :end_time, null: false
      t.string :timezone
      t.boolean :all_day, default: false

      # Match Info
      t.references :match, foreign_key: true, type: :uuid
      t.string :opponent_name
      t.string :location
      t.string :meeting_url

      # Participants
      t.uuid :required_players, array: true, default: []
      t.uuid :optional_players, array: true, default: []

      # Organization
      t.string :status, default: 'scheduled'
      t.text :tags, array: true, default: []
      t.string :color

      # Recurrence
      t.boolean :is_recurring, default: false
      t.string :recurrence_rule
      t.date :recurrence_end_date

      # Reminders
      t.integer :reminder_minutes, array: true, default: []

      # Metadata
      t.references :created_by, foreign_key: { to_table: :users }, type: :uuid
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :schedules, :start_time
    add_index :schedules, :event_type
    add_index :schedules, :status
  end
end