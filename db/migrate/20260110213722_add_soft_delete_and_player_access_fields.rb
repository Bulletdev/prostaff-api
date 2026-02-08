# frozen_string_literal: true

# Migration to add soft delete and player access fields
#
# This migration adds:
# - deleted_at: Timestamp for soft delete (when player is removed from team)
# - removed_reason: Why the player was removed
# - player_email: Email for individual player access
# - player_password_digest: Password hash for player authentication
# - last_login_at: Track when player last logged in
# - player_access_enabled: Flag to enable/disable player access
#
# Rationale:
# - Players should not be permanently deleted (preserves match history)
# - When a player leaves a team, they can be marked as removed but data is kept
# - Players can be transferred to another organization later
# - Individual player access allows players to view their own stats
class AddSoftDeleteAndPlayerAccessFields < ActiveRecord::Migration[7.2]
  def change
    # Soft delete fields
    add_column :players, :deleted_at, :datetime, comment: 'Soft delete timestamp - when player was removed from team'
    add_column :players, :removed_reason, :text, comment: 'Reason for removal (contract end, transfer, etc)'
    add_column :players, :previous_organization_id, :uuid, comment: 'Previous organization if transferred'

    # Player individual access fields
    add_column :players, :player_email, :string, comment: 'Email for player individual access'
    add_column :players, :player_password_digest, :string, comment: 'Password hash for player authentication'
    add_column :players, :last_login_at, :datetime, comment: 'Last login timestamp for player access'
    add_column :players, :player_access_enabled, :boolean, default: false, comment: 'Enable/disable individual player access'
    add_column :players, :access_token_jti, :string, comment: 'JWT token identifier for player session'

    # Indexes for performance
    add_index :players, :deleted_at, comment: 'Index for soft delete queries'
    add_index :players, :player_email, unique: true, where: 'player_email IS NOT NULL', comment: 'Unique email for player access'
    add_index :players, :player_access_enabled, comment: 'Quick lookup for players with access enabled'
    add_index :players, :previous_organization_id, comment: 'Track player transfers'

    # Add foreign key for previous organization
    add_foreign_key :players, :organizations, column: :previous_organization_id, on_delete: :nullify
  end
end
