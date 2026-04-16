# frozen_string_literal: true

# Persists an audit log entry asynchronously so that write-heavy models
# (Player, Match, etc.) do not pay the cost of a synchronous INSERT on every
# update.
#
# Retried up to 3 times with Sidekiq's default back-off before being moved to
# the dead queue.  Audit loss is preferable to blocking the request thread.
#
# @example Enqueue from a model after_update_commit callback
#   AuditLogJob.perform_later(
#     organization_id: organization_id,
#     entity_type:     'Player',
#     entity_id:       id,
#     old_values:      saved_changes.transform_values(&:first),
#     new_values:      saved_changes.transform_values(&:last)
#   )
class AuditLogJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  # @param organization_id [String] UUID of the owning organization
  # @param entity_type [String] ActiveRecord model name (e.g. 'Player')
  # @param entity_id [String] UUID of the changed record
  # @param old_values [Hash] attribute values before the update
  # @param new_values [Hash] attribute values after the update
  # @param user_id [String, nil] UUID of the user who triggered the change (optional)
  def perform(organization_id:, entity_type:, entity_id:, old_values:, new_values:, user_id: nil)
    AuditLog.create!(
      organization_id: organization_id,
      action: 'update',
      entity_type: entity_type,
      entity_id: entity_id,
      old_values: old_values,
      new_values: new_values,
      user_id: user_id
    )
  end
end
