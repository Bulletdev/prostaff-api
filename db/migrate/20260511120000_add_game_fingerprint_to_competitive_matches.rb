# frozen_string_literal: true

class AddGameFingerprintToCompetitiveMatches < ActiveRecord::Migration[7.1]
  def up
    add_column :competitive_matches, :game_fingerprint, :string

    # Populate fingerprints on existing records before the unique index is created.
    # Fingerprint = md5(org_id | match_date_day | game_number | normalized_opponent).
    # Partial: records missing match_date or opponent_team_name are left NULL and
    # excluded from the unique index (where clause below).
    execute <<~SQL
      UPDATE competitive_matches
      SET game_fingerprint = md5(
        organization_id::text || '|' ||
        (match_date AT TIME ZONE 'UTC')::date::text || '|' ||
        COALESCE(game_number::text, '1') || '|' ||
        lower(trim(opponent_team_name))
      )
      WHERE game_fingerprint IS NULL
        AND match_date IS NOT NULL
        AND opponent_team_name IS NOT NULL
        AND trim(opponent_team_name) <> ''
    SQL

    # Partial unique index — only covers records with a fingerprint.
    # Records without match_date or opponent_team_name remain unrestricted.
    add_index :competitive_matches,
              %i[organization_id game_fingerprint],
              unique: true,
              where: "game_fingerprint IS NOT NULL",
              name: "idx_comp_matches_org_fingerprint_unique"
  end

  def down
    remove_index :competitive_matches, name: "idx_comp_matches_org_fingerprint_unique"
    remove_column :competitive_matches, :game_fingerprint
  end
end
