# frozen_string_literal: true

class CreateTournaments < ActiveRecord::Migration[7.2]
  def change
    create_table :tournaments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string  :name,                null: false
      t.string  :game,                null: false, default: "league_of_legends"
      t.string  :format,              null: false, default: "double_elimination"

      # draft | registration_open | seeding | in_progress | finished | cancelled
      t.string  :status,              null: false, default: "draft"

      t.integer :max_teams,           null: false, default: 16
      t.integer :entry_fee_cents,     null: false, default: 0
      t.integer :prize_pool_cents,    null: false, default: 0

      # Bo format for group stage, semifinals, final
      t.integer :bo_format,           null: false, default: 3

      t.string  :current_round_label
      t.text    :rules

      t.datetime :registration_closes_at
      t.datetime :scheduled_start_at
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :tournaments, :status
    add_index :tournaments, :scheduled_start_at
  end
end
