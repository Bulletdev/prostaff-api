# frozen_string_literal: true

# Creates the server-side queue tables for the inhouse system.
#
# InhouseQueue — the queue session for a given org
#   status: open (accepting entries) | check_in (players confirming presence) | closed
#   check_in_deadline: set when status moves to check_in
#
# InhouseQueueEntry — one player slot in the queue
#   role: top|jungle|mid|adc|support (max 2 per role per queue)
#   tier_snapshot: player tier at join time, used for draft algorithm
#   checked_in: true once coach/player confirms presence during check_in phase
#
class CreateInhouseQueues < ActiveRecord::Migration[7.2]
  def change
    create_table :inhouse_queues, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string     :status, default: 'open', null: false
      t.datetime   :check_in_deadline
      t.uuid       :created_by_user_id, null: false

      t.timestamps
    end

    add_foreign_key :inhouse_queues, :users, column: :created_by_user_id

    create_table :inhouse_queue_entries, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :inhouse_queue, null: false, foreign_key: true, type: :uuid
      t.references :player,        null: false, foreign_key: true, type: :uuid
      t.string     :role,          null: false
      t.string     :tier_snapshot
      t.boolean    :checked_in, default: false, null: false
      t.datetime   :checked_in_at

      t.timestamps
    end

    add_index :inhouse_queue_entries, %i[inhouse_queue_id player_id], unique: true
    add_index :inhouse_queue_entries, %i[inhouse_queue_id role]
  end
end
