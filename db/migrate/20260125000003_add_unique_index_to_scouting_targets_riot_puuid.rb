# frozen_string_literal: true

class AddUniqueIndexToScoutingTargetsRiotPuuid < ActiveRecord::Migration[7.1]
  def change
    # Remove old non-unique index
    remove_index :scouting_targets, :riot_puuid if index_exists?(:scouting_targets, :riot_puuid)

    # Add unique composite index scoped to organization
    # This allows the same player (PUUID) to be a scouting target in multiple organizations
    add_index :scouting_targets, %i[organization_id riot_puuid],
              unique: true,
              name: 'index_scouting_targets_on_org_and_puuid',
              where: "riot_puuid IS NOT NULL"
  end
end
