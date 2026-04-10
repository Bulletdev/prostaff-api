# frozen_string_literal: true

class MakePlayerOrganizationOptional < ActiveRecord::Migration[7.2]
  def up
    # Allow players without an organization (free agents self-registered via ArenaBR)
    # Removes the NOT NULL constraint — existing players keep their org_id unchanged
    change_column_null :players, :organization_id, true
  end

  def down
    # Before reverting, ensure no null rows exist
    execute <<~SQL
      UPDATE players SET organization_id = (SELECT id FROM organizations ORDER BY created_at LIMIT 1)
      WHERE organization_id IS NULL;
    SQL
    change_column_null :players, :organization_id, false
  end
end
