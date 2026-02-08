# frozen_string_literal: true

class RefactorScoutingTargetsToGlobal < ActiveRecord::Migration[7.1]
  def up
    # Step 1: Migrate data from scouting_targets to watchlists
    # This must happen BEFORE we drop the organization_id column
    migrate_to_watchlists

    # Step 2: Disable RLS temporarily to make schema changes
    execute <<-SQL
      ALTER TABLE scouting_targets DISABLE ROW LEVEL SECURITY;
    SQL

    # Step 3: Drop RLS policies (all variants)
    execute <<-SQL
      DROP POLICY IF EXISTS scouting_targets_org_delete ON scouting_targets;
      DROP POLICY IF EXISTS scouting_targets_org_update ON scouting_targets;
      DROP POLICY IF EXISTS scouting_targets_org_insert ON scouting_targets;
      DROP POLICY IF EXISTS scouting_targets_org_isolation ON scouting_targets;
      DROP POLICY IF EXISTS scouting_targets_select_policy ON scouting_targets;
      DROP POLICY IF EXISTS scouting_targets_insert_policy ON scouting_targets;
      DROP POLICY IF EXISTS scouting_targets_update_policy ON scouting_targets;
      DROP POLICY IF EXISTS scouting_targets_delete_policy ON scouting_targets;
    SQL

    # Step 4: Remove org-specific columns (moving to watchlists)
    remove_column :scouting_targets, :organization_id, :uuid
    remove_column :scouting_targets, :added_by_id, :uuid
    remove_column :scouting_targets, :assigned_to_id, :uuid
    remove_column :scouting_targets, :priority, :string
    remove_column :scouting_targets, :last_reviewed, :datetime

    # Move notes to watchlist (keep notes column for now, will contain player-specific notes)
    # The watchlist will have org-specific notes

    # Step 5: Make riot_puuid globally unique (was scoped to org before)
    remove_index :scouting_targets, name: 'index_scouting_targets_on_riot_puuid_and_organization_id', if_exists: true
    add_index :scouting_targets, :riot_puuid, unique: true, where: "riot_puuid IS NOT NULL"

    # Step 6: Add fields for global player data
    add_column :scouting_targets, :real_name, :string unless column_exists?(:scouting_targets, :real_name)
    add_column :scouting_targets, :avatar_url, :string unless column_exists?(:scouting_targets, :avatar_url)
    add_column :scouting_targets, :profile_icon_id, :integer unless column_exists?(:scouting_targets, :profile_icon_id)
    add_column :scouting_targets, :peak_tier, :string unless column_exists?(:scouting_targets, :peak_tier)
    add_column :scouting_targets, :peak_rank, :string unless column_exists?(:scouting_targets, :peak_rank)
    add_column :scouting_targets, :last_api_sync_at, :datetime unless column_exists?(:scouting_targets, :last_api_sync_at)

    # Step 7: Add indexes for global queries
    add_index :scouting_targets, :status unless index_exists?(:scouting_targets, :status)
    add_index :scouting_targets, :region unless index_exists?(:scouting_targets, :region)
    add_index :scouting_targets, :role unless index_exists?(:scouting_targets, :role)
    add_index :scouting_targets, :current_tier unless index_exists?(:scouting_targets, :current_tier)
    add_index :scouting_targets, :summoner_name unless index_exists?(:scouting_targets, :summoner_name)

    # Step 8: NO RLS on scouting_targets (global visibility)
    # Watchlists will have RLS for org-specific data
  end

  def down
    # Reverse the migration
    remove_index :scouting_targets, :summoner_name, if_exists: true
    remove_index :scouting_targets, :current_tier, if_exists: true
    remove_index :scouting_targets, :role, if_exists: true
    remove_index :scouting_targets, :region, if_exists: true
    remove_index :scouting_targets, :status, if_exists: true

    remove_column :scouting_targets, :last_api_sync_at, if_exists: true
    remove_column :scouting_targets, :peak_rank, if_exists: true
    remove_column :scouting_targets, :peak_tier, if_exists: true
    remove_column :scouting_targets, :profile_icon_id, if_exists: true
    remove_column :scouting_targets, :avatar_url, if_exists: true
    remove_column :scouting_targets, :real_name, if_exists: true

    remove_index :scouting_targets, :riot_puuid, if_exists: true

    add_reference :scouting_targets, :organization, type: :uuid, foreign_key: true
    add_reference :scouting_targets, :added_by, type: :uuid, foreign_key: { to_table: :users }
    add_reference :scouting_targets, :assigned_to, type: :uuid, foreign_key: { to_table: :users }
    add_column :scouting_targets, :priority, :string
    add_column :scouting_targets, :last_reviewed, :datetime

    execute <<-SQL
      ALTER TABLE scouting_targets ENABLE ROW LEVEL SECURITY;

      CREATE POLICY scouting_targets_org_isolation ON scouting_targets
        USING (organization_id::text = current_setting('app.current_organization_id', true));

      CREATE POLICY scouting_targets_org_insert ON scouting_targets
        FOR INSERT
        WITH CHECK (organization_id::text = current_setting('app.current_organization_id', true));

      CREATE POLICY scouting_targets_org_update ON scouting_targets
        FOR UPDATE
        USING (organization_id::text = current_setting('app.current_organization_id', true));

      CREATE POLICY scouting_targets_org_delete ON scouting_targets
        FOR DELETE
        USING (organization_id::text = current_setting('app.current_organization_id', true));
    SQL

    # Note: We don't migrate data back, this is destructive
    say "WARNING: Data migration back is not implemented. Watchlist data will be lost."
  end

  private

  def migrate_to_watchlists
    # Disable RLS temporarily to read all data
    execute "SET row_security = off;"

    # Get all scouting targets with their org-specific data
    say_with_time "Migrating scouting targets to watchlists..." do
      execute <<-SQL
        -- First, deduplicate scouting_targets by riot_puuid
        -- Keep the oldest record for each riot_puuid as canonical
        WITH canonical_targets AS (
          SELECT DISTINCT ON (riot_puuid) id, riot_puuid
          FROM scouting_targets
          WHERE riot_puuid IS NOT NULL
          ORDER BY riot_puuid, created_at ASC
        ),
        -- For each non-canonical target, create a watchlist entry
        watchlist_data AS (
          SELECT
            st.organization_id,
            ct.id as canonical_target_id,
            st.added_by_id,
            st.assigned_to_id,
            st.priority,
            st.status,
            st.notes,
            st.last_reviewed,
            st.metadata,
            st.created_at,
            st.updated_at
          FROM scouting_targets st
          JOIN canonical_targets ct ON st.riot_puuid = ct.riot_puuid
        )
        -- Insert into watchlists (including canonical targets' org data)
        INSERT INTO scouting_watchlists (
          id,
          organization_id,
          scouting_target_id,
          added_by_id,
          assigned_to_id,
          priority,
          status,
          notes,
          last_reviewed,
          metadata,
          created_at,
          updated_at
        )
        SELECT
          gen_random_uuid(),
          organization_id,
          canonical_target_id,
          added_by_id,
          assigned_to_id,
          COALESCE(priority, 'medium'),
          COALESCE(status, 'watching'),
          notes,
          last_reviewed,
          COALESCE(metadata, '{}'::jsonb),
          created_at,
          updated_at
        FROM watchlist_data
        ON CONFLICT (organization_id, scouting_target_id) DO NOTHING;

        -- Delete duplicate scouting_targets (keep only canonical ones)
        DELETE FROM scouting_targets
        WHERE id NOT IN (
          SELECT DISTINCT ON (riot_puuid) id
          FROM scouting_targets
          WHERE riot_puuid IS NOT NULL
          ORDER BY riot_puuid, created_at ASC
        )
        AND riot_puuid IS NOT NULL;

        -- For targets without riot_puuid, keep all and create watchlist entries
        INSERT INTO scouting_watchlists (
          id,
          organization_id,
          scouting_target_id,
          added_by_id,
          assigned_to_id,
          priority,
          status,
          notes,
          last_reviewed,
          metadata,
          created_at,
          updated_at
        )
        SELECT
          gen_random_uuid(),
          organization_id,
          id,
          added_by_id,
          assigned_to_id,
          COALESCE(priority, 'medium'),
          COALESCE(status, 'watching'),
          notes,
          last_reviewed,
          COALESCE(metadata, '{}'::jsonb),
          created_at,
          updated_at
        FROM scouting_targets
        WHERE riot_puuid IS NULL
        ON CONFLICT (organization_id, scouting_target_id) DO NOTHING;
      SQL
    end

    # Re-enable RLS
    execute "SET row_security = on;"
  end
end
