# frozen_string_literal: true

# Adds extended stats fields to player_match_stats.
# Fields sourced from Riot Match v5 API (all confirmed available in participant object).
# Ping fields added in API patch 12.10+.
# Challenges fields (cs_at_10, turret_plates_destroyed) use safe access - may be nil for older matches.
class AddExtendedStatsToPlayerMatchStats < ActiveRecord::Migration[7.1]
  def change
    change_table :player_match_stats, bulk: true do |t|
      # Jungle / objectives
      t.integer :neutral_minions_killed
      t.integer :objectives_stolen, default: 0
      t.integer :turret_plates_destroyed

      # Combat extended
      t.integer :crowd_control_score
      t.integer :total_time_dead
      t.integer :damage_to_turrets
      t.integer :damage_shielded_teammates
      t.integer :healing_to_teammates

      # Early game (from challenges object, may be nil)
      t.integer :cs_at_10

      # Spell casts
      t.integer :spell_q_casts
      t.integer :spell_w_casts
      t.integer :spell_e_casts
      t.integer :spell_r_casts
      t.integer :summoner_spell_1_casts
      t.integer :summoner_spell_2_casts

      # Ping data (jsonb keyed by ping type)
      t.jsonb :pings, default: {}
    end

    add_index :player_match_stats, :objectives_stolen,
              name: 'idx_pms_objectives_stolen',
              where: 'objectives_stolen > 0'

    add_index :player_match_stats, :crowd_control_score,
              name: 'idx_pms_cc_score'
  end
end
