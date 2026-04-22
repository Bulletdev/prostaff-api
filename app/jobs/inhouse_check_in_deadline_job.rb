# frozen_string_literal: true

# Enforces the inhouse queue check-in deadline.
#
# Scheduled from InhouseQueuesController#start_checkin when the queue transitions
# to check_in state. Fires at check_in_deadline.
#
# Behavior at deadline:
#   - Removes entries for players who did not check in.
#   - If fewer than 2 checked-in players remain, closes the queue automatically.
#   - Broadcasts the updated queue state via Action Cable.
#
# Scheduling:
#   InhouseCheckInDeadlineJob.set(wait_until: deadline).perform_later(queue.id)
class InhouseCheckInDeadlineJob < ApplicationJob
  queue_as :default

  def perform(queue_id)
    queue = InhouseQueue.includes(inhouse_queue_entries: :player).find_by(id: queue_id)
    return unless queue
    return unless queue.check_in?
    return if Time.current < queue.check_in_deadline

    process_expired_check_in(queue)
    record_job_heartbeat
  end

  private

  def process_expired_check_in(queue)
    unchecked = queue.inhouse_queue_entries.where(checked_in: false)
    removed_count = unchecked.count
    unchecked.destroy_all

    checked_in_count = queue.inhouse_queue_entries.where(checked_in: true).count

    if checked_in_count < 2
      queue.update!(status: 'closed')
      Rails.logger.info(
        event: 'inhouse_queue_closed_deadline',
        queue_id: queue.id,
        org_id: queue.organization_id,
        checked_in: checked_in_count,
        removed: removed_count
      )
      broadcast_closed(queue, removed_count)
    else
      Rails.logger.info(
        event: 'inhouse_queue_check_in_expired',
        queue_id: queue.id,
        org_id: queue.organization_id,
        checked_in: checked_in_count,
        removed: removed_count
      )
      broadcast_updated(queue, removed_count)
    end
  end

  def broadcast_closed(queue, removed_count)
    ActionCable.server.broadcast(
      "inhouse_queue_#{queue.organization_id}",
      {
        event: 'check_in_expired',
        queue_id: queue.id,
        status: 'closed',
        removed_count: removed_count,
        message: 'Queue closed: not enough players checked in before deadline'
      }
    )
  end

  def broadcast_updated(queue, removed_count)
    ActionCable.server.broadcast(
      "inhouse_queue_#{queue.organization_id}",
      {
        event: 'check_in_expired',
        queue_id: queue.id,
        status: queue.status,
        removed_count: removed_count,
        queue: queue.reload.serialize(detailed: true)
      }
    )
  end
end
