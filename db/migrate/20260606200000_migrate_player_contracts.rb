# frozen_string_literal: true

# One-time data migration: seeds the contracts table from legacy player fields.
#
# Each player with a non-null contract_end_date receives exactly one Contract record
# unless one already exists (idempotent guard). The status is inferred from whether
# the end_date is in the past. start_date falls back to the player's created_at when
# the contract_start_date column is blank.
#
# The migration uses save!(validate: false) because:
#   - Historical records may have end_date <= start_date (data entered incorrectly).
#   - The no_overlapping_active_contract callback runs a query that may reference
#     contracts created earlier in this same batch — validation: false avoids false
#     positives while still inserting the row.
#
# down: deletes all contracts (destructive) — only safe to call on a clean environment.
class MigratePlayerContracts < ActiveRecord::Migration[7.1]
  def up
    owner_by_org    = User.where(role: 'owner').pluck(:organization_id, :id).to_h
    fallback_user   = User.where(role: 'admin').limit(1).pick(:id)

    created_count = 0
    skipped_count = 0

    Player.where.not(contract_end_date: nil).find_each do |player|
      if Contract.exists?(player_id: player.id, organization_id: player.organization_id)
        skipped_count += 1
        next
      end

      creator_id = owner_by_org[player.organization_id] || fallback_user

      unless creator_id
        Rails.logger.warn("[MigratePlayerContracts] No owner or admin found for org=#{player.organization_id}, skipping player=#{player.id}")
        skipped_count += 1
        next
      end

      status     = player.contract_end_date >= Date.current ? 'active' : 'expired'
      start_date = player.contract_start_date || player.created_at.to_date

      contract = Contract.new(
        organization_id: player.organization_id,
        player_id: player.id,
        contract_type: 'player',
        status: status,
        start_date: start_date,
        end_date: player.contract_end_date,
        base_salary: player.salary || 0,
        salary_currency: 'BRL',
        salary_period: 'monthly',
        created_by_id: creator_id
      )
      contract.save!(validate: false)
      created_count += 1
    end

    Rails.logger.info("[MigratePlayerContracts] done: created=#{created_count} skipped=#{skipped_count}")
    say "MigratePlayerContracts: created=#{created_count} skipped=#{skipped_count}"
  end

  def down
    Contract.delete_all
  end
end
