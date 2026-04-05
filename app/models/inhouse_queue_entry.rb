# frozen_string_literal: true

# A single player slot in an InhouseQueue.
# Tracks role, tier at join time, and check-in status.
class InhouseQueueEntry < ApplicationRecord
  belongs_to :inhouse_queue
  belongs_to :player

  validates :role, presence: true, inclusion: { in: InhouseQueue::ROLES }
  validates :player_id, uniqueness: { scope: :inhouse_queue_id, message: 'is already in this queue' }

  def serialize
    {
      id: id,
      player_id: player_id,
      player_name: player&.summoner_name,
      role: role,
      tier_snapshot: tier_snapshot,
      checked_in: checked_in,
      checked_in_at: checked_in_at
    }
  end
end
