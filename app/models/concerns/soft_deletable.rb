# frozen_string_literal: true

# Soft delete functionality for models
#
# This concern provides soft delete capabilities by marking records as deleted
# instead of actually removing them from the database. This preserves data
# integrity and allows for potential restoration.
#
# @example Including in a model
#   class Player < ApplicationRecord
#     include SoftDeletable
#   end
#
# @example Soft deleting a record
#   player.soft_delete!(reason: 'Contract ended')
#
# @example Restoring a deleted record
#   player.restore!
#
# @example Querying with deleted records
#   Player.with_deleted.where(role: 'mid')
#   Player.only_deleted.where(organization: org)
#
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    # Default scope: exclude soft-deleted records
    default_scope { where(deleted_at: nil) }

    # Scopes
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }
    scope :deleted_since, ->(date) { unscope(where: :deleted_at).where('deleted_at >= ?', date) }
  end

  # Check if record is soft deleted
  # @return [Boolean] true if record has been soft deleted
  def deleted?
    deleted_at.present?
  end

  # Soft delete the record with optional reason and previous organization tracking
  # @param reason [String] Reason for removal (e.g., 'Contract ended', 'Transferred')
  # @param previous_org_id [UUID] Previous organization ID if transferring
  # @return [Boolean] true if successful
  def soft_delete!(reason: nil, previous_org_id: nil)
    update_columns(
      deleted_at: Time.current,
      removed_reason: reason,
      previous_organization_id: previous_org_id,
      status: 'removed'
    )
  end

  # Restore a soft-deleted record
  # @param new_status [String] Status to set after restoration (default: 'inactive')
  # @return [Boolean] true if successful
  def restore!(new_status: 'inactive')
    update_columns(
      deleted_at: nil,
      removed_reason: nil,
      status: new_status
    )
  end

  # Check if record can be permanently deleted
  # Override this method in models to add specific business logic
  # @return [Boolean] true if record can be destroyed
  def can_permanently_delete?
    false # Default: prevent permanent deletion
  end

  # Override destroy to use soft delete instead
  def destroy
    soft_delete!
  end

  # Override destroy! to use soft delete instead
  def destroy!
    soft_delete!
  end

  # Force permanent deletion (use with extreme caution)
  def destroy_permanently!
    raise 'Cannot permanently delete this record' unless can_permanently_delete?

    really_destroy!
  end

  private

  # Internal method for actual deletion
  def really_destroy!
    # Temporarily remove default scope to allow actual deletion
    self.class.unscoped { super }
  end
end
