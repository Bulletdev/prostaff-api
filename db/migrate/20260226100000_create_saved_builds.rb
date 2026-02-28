# frozen_string_literal: true

# Creates the saved_builds table for the Meta Intelligence module.
#
# Stores build configurations for champions, either:
#   - manually created by coaches (data_source: 'manual')
#   - auto-aggregated from match history (data_source: 'aggregated')
#
# Performance metrics (win_rate, average_kda, etc.) are calculated
# asynchronously by BuildAggregatorService / UpdateMetaStatsJob.
class CreateSavedBuilds < ActiveRecord::Migration[7.1]
  def change
    create_table :saved_builds, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :created_by, null: true, foreign_key: { to_table: :users }, type: :uuid

      # Build identity
      t.string :champion,      null: false
      t.string :role
      t.string :patch_version

      # Item data — integer IDs from Riot Data Dragon
      t.integer :items,            array: true, default: []
      t.integer :item_build_order, array: true, default: []
      t.integer :trinket

      # Rune data — integer IDs from Riot Data Dragon
      t.integer :runes, array: true, default: []
      t.string  :primary_rune_tree
      t.string  :secondary_rune_tree

      # Summoner spells — string keys (e.g. "SummonerFlash")
      t.string :summoner_spell_1
      t.string :summoner_spell_2

      # Performance metrics — computed by BuildAggregatorService
      t.decimal :win_rate,            precision: 5, scale: 2, default: 0.0
      t.integer :games_played,        default: 0,   null: false
      t.decimal :average_kda,         precision: 5, scale: 2, default: 0.0
      t.decimal :average_cs_per_min,  precision: 5, scale: 2, default: 0.0
      t.decimal :average_damage_share, precision: 5, scale: 2, default: 0.0

      # Metadata
      t.string  :title
      t.text    :notes
      t.boolean :is_public,          null: false, default: false

      # Source tracking
      # 'manual'     — created directly by a coach
      # 'aggregated' — auto-generated from player_match_stats
      t.string :data_source, null: false, default: 'manual'

      # SHA256 of sorted item IDs — used for deduplication of aggregated builds
      t.string :items_fingerprint

      t.timestamps
    end

    # Lookup indexes for common filter combinations
    add_index :saved_builds, %i[organization_id champion role],
              name: 'idx_saved_builds_org_champion_role'

    add_index :saved_builds, %i[organization_id patch_version],
              name: 'idx_saved_builds_org_patch'

    add_index :saved_builds, %i[organization_id is_public],
              name: 'idx_saved_builds_org_public'

    # Ranking index for tier list queries
    add_index :saved_builds, %i[organization_id win_rate],
              name: 'idx_saved_builds_win_rate'

    # Prevent duplicate aggregated builds for the same champion + role + item set
    add_index :saved_builds,
              %i[organization_id champion role items_fingerprint],
              unique: true,
              where: "data_source = 'aggregated'",
              name: 'idx_saved_builds_aggregated_unique'
  end
end
