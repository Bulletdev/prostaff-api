# frozen_string_literal: true

class AddRlsToScoutingTargets < ActiveRecord::Migration[7.2]
  def up
    execute <<-SQL
      -- Enable RLS on scouting_targets
      ALTER TABLE scouting_targets ENABLE ROW LEVEL SECURITY;

      -- Policy 1: SELECT - Everyone can read (authenticated users)
      -- This allows all orgs to see all free agents
      CREATE POLICY scouting_targets_select_policy ON scouting_targets
        FOR SELECT
        USING (
          -- Allow if user is authenticated (has current_user_id set)
          current_setting('app.current_user_id', true) IS NOT NULL
          AND current_setting('app.current_user_id', true) != ''
        );

      -- Policy 2: INSERT - Only system/authenticated users can create
      -- This prevents direct database manipulation
      CREATE POLICY scouting_targets_insert_policy ON scouting_targets
        FOR INSERT
        WITH CHECK (
          -- Must be authenticated
          current_setting('app.current_user_id', true) IS NOT NULL
          AND current_setting('app.current_user_id', true) != ''
        );

      -- Policy 3: UPDATE - Only system/authenticated users can update
      -- This prevents unauthorized modifications
      CREATE POLICY scouting_targets_update_policy ON scouting_targets
        FOR UPDATE
        USING (
          -- Must be authenticated
          current_setting('app.current_user_id', true) IS NOT NULL
          AND current_setting('app.current_user_id', true) != ''
        );

      -- Policy 4: DELETE - Only system/authenticated users can delete
      -- This prevents unauthorized deletions
      CREATE POLICY scouting_targets_delete_policy ON scouting_targets
        FOR DELETE
        USING (
          -- Must be authenticated
          current_setting('app.current_user_id', true) IS NOT NULL
          AND current_setting('app.current_user_id', true) != ''
        );
    SQL
  end

  def down
    execute <<-SQL
      -- Drop all policies
      DROP POLICY IF EXISTS scouting_targets_delete_policy ON scouting_targets;
      DROP POLICY IF EXISTS scouting_targets_update_policy ON scouting_targets;
      DROP POLICY IF EXISTS scouting_targets_insert_policy ON scouting_targets;
      DROP POLICY IF EXISTS scouting_targets_select_policy ON scouting_targets;

      -- Disable RLS
      ALTER TABLE scouting_targets DISABLE ROW LEVEL SECURITY;
    SQL
  end
end
