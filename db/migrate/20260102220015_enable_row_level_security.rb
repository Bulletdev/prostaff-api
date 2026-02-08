class EnableRowLevelSecurity < ActiveRecord::Migration[7.2]
  def up
    # Enable RLS on all organization-scoped tables
    enable_rls_on_table(:users)
    enable_rls_on_table(:players)
    enable_rls_on_table(:matches)
    enable_rls_on_table(:player_match_stats)
    enable_rls_on_table(:champion_pools)
    enable_rls_on_table(:scouting_targets)
    enable_rls_on_table(:schedules)
    enable_rls_on_table(:vod_reviews)
    enable_rls_on_table(:vod_timestamps)
    enable_rls_on_table(:team_goals)
    enable_rls_on_table(:audit_logs)
    enable_rls_on_table(:scrims)
    enable_rls_on_table(:competitive_matches)

    # Create function to get current user's organization_id from JWT
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.user_organization_id()
      RETURNS uuid
      LANGUAGE sql
      STABLE
      AS $$
        SELECT COALESCE(
          current_setting('app.current_organization_id', TRUE)::uuid,
          NULL
        );
      $$;
    SQL

    # Create function to get current user's ID from JWT
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.current_user_id()
      RETURNS uuid
      LANGUAGE sql
      STABLE
      AS $$
        SELECT COALESCE(
          current_setting('app.current_user_id', TRUE)::uuid,
          NULL
        );
      $$;
    SQL

    # Create function to check if user is admin
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.is_admin()
      RETURNS boolean
      LANGUAGE sql
      STABLE
      AS $$
        SELECT COALESCE(
          current_setting('app.user_role', TRUE) = 'admin',
          FALSE
        );
      $$;
    SQL

    # RLS Policies for USERS table
    create_policy(:users, :select, 'users_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:users, :insert, 'users_insert_policy',
      'organization_id = public.user_organization_id() AND public.is_admin()')
    create_policy(:users, :update, 'users_update_policy',
      'organization_id = public.user_organization_id() AND (public.is_admin() OR id = public.current_user_id())')
    create_policy(:users, :delete, 'users_delete_policy',
      'organization_id = public.user_organization_id() AND public.is_admin()')

    # RLS Policies for PLAYERS table
    create_policy(:players, :select, 'players_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:players, :insert, 'players_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:players, :update, 'players_update_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:players, :delete, 'players_delete_policy',
      'organization_id = public.user_organization_id() AND public.is_admin()')

    # RLS Policies for MATCHES table
    create_policy(:matches, :select, 'matches_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:matches, :insert, 'matches_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:matches, :update, 'matches_update_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:matches, :delete, 'matches_delete_policy',
      'organization_id = public.user_organization_id() AND public.is_admin()')

    # RLS Policies for PLAYER_MATCH_STATS table (via player relationship)
    execute <<-SQL
      CREATE POLICY player_match_stats_select_policy ON player_match_stats
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM players
          WHERE players.id = player_match_stats.player_id
          AND players.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY player_match_stats_insert_policy ON player_match_stats
      FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM players
          WHERE players.id = player_match_stats.player_id
          AND players.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY player_match_stats_update_policy ON player_match_stats
      FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM players
          WHERE players.id = player_match_stats.player_id
          AND players.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY player_match_stats_delete_policy ON player_match_stats
      FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM players
          WHERE players.id = player_match_stats.player_id
          AND players.organization_id = public.user_organization_id()
        )
        AND public.is_admin()
      );
    SQL

    # RLS Policies for CHAMPION_POOLS table (via player relationship)
    execute <<-SQL
      CREATE POLICY champion_pools_select_policy ON champion_pools
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM players
          WHERE players.id = champion_pools.player_id
          AND players.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY champion_pools_insert_policy ON champion_pools
      FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM players
          WHERE players.id = champion_pools.player_id
          AND players.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY champion_pools_update_policy ON champion_pools
      FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM players
          WHERE players.id = champion_pools.player_id
          AND players.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY champion_pools_delete_policy ON champion_pools
      FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM players
          WHERE players.id = champion_pools.player_id
          AND players.organization_id = public.user_organization_id()
        )
      );
    SQL

    # RLS Policies for SCOUTING_TARGETS table
    create_policy(:scouting_targets, :select, 'scouting_targets_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:scouting_targets, :insert, 'scouting_targets_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:scouting_targets, :update, 'scouting_targets_update_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:scouting_targets, :delete, 'scouting_targets_delete_policy',
      'organization_id = public.user_organization_id()')

    # RLS Policies for SCHEDULES table
    create_policy(:schedules, :select, 'schedules_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:schedules, :insert, 'schedules_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:schedules, :update, 'schedules_update_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:schedules, :delete, 'schedules_delete_policy',
      'organization_id = public.user_organization_id()')

    # RLS Policies for VOD_REVIEWS table
    create_policy(:vod_reviews, :select, 'vod_reviews_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:vod_reviews, :insert, 'vod_reviews_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:vod_reviews, :update, 'vod_reviews_update_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:vod_reviews, :delete, 'vod_reviews_delete_policy',
      'organization_id = public.user_organization_id()')

    # RLS Policies for VOD_TIMESTAMPS table (via vod_review relationship)
    execute <<-SQL
      CREATE POLICY vod_timestamps_select_policy ON vod_timestamps
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM vod_reviews
          WHERE vod_reviews.id = vod_timestamps.vod_review_id
          AND vod_reviews.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY vod_timestamps_insert_policy ON vod_timestamps
      FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM vod_reviews
          WHERE vod_reviews.id = vod_timestamps.vod_review_id
          AND vod_reviews.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY vod_timestamps_update_policy ON vod_timestamps
      FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM vod_reviews
          WHERE vod_reviews.id = vod_timestamps.vod_review_id
          AND vod_reviews.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY vod_timestamps_delete_policy ON vod_timestamps
      FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM vod_reviews
          WHERE vod_reviews.id = vod_timestamps.vod_review_id
          AND vod_reviews.organization_id = public.user_organization_id()
        )
      );
    SQL

    # RLS Policies for TEAM_GOALS table
    create_policy(:team_goals, :select, 'team_goals_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:team_goals, :insert, 'team_goals_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:team_goals, :update, 'team_goals_update_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:team_goals, :delete, 'team_goals_delete_policy',
      'organization_id = public.user_organization_id()')

    # RLS Policies for AUDIT_LOGS table
    create_policy(:audit_logs, :select, 'audit_logs_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:audit_logs, :insert, 'audit_logs_insert_policy',
      'organization_id = public.user_organization_id()')
    # Audit logs should not be updated or deleted
    
    # RLS Policies for SCRIMS table
    create_policy(:scrims, :select, 'scrims_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:scrims, :insert, 'scrims_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:scrims, :update, 'scrims_update_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:scrims, :delete, 'scrims_delete_policy',
      'organization_id = public.user_organization_id()')

    # RLS Policies for COMPETITIVE_MATCHES table
    create_policy(:competitive_matches, :select, 'competitive_matches_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:competitive_matches, :insert, 'competitive_matches_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:competitive_matches, :update, 'competitive_matches_update_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:competitive_matches, :delete, 'competitive_matches_delete_policy',
      'organization_id = public.user_organization_id() AND public.is_admin()')
  end

  def down
    # Drop all policies
    drop_policy(:users, 'users_select_policy')
    drop_policy(:users, 'users_insert_policy')
    drop_policy(:users, 'users_update_policy')
    drop_policy(:users, 'users_delete_policy')

    drop_policy(:players, 'players_select_policy')
    drop_policy(:players, 'players_insert_policy')
    drop_policy(:players, 'players_update_policy')
    drop_policy(:players, 'players_delete_policy')

    drop_policy(:matches, 'matches_select_policy')
    drop_policy(:matches, 'matches_insert_policy')
    drop_policy(:matches, 'matches_update_policy')
    drop_policy(:matches, 'matches_delete_policy')

    drop_policy(:player_match_stats, 'player_match_stats_select_policy')
    drop_policy(:player_match_stats, 'player_match_stats_insert_policy')
    drop_policy(:player_match_stats, 'player_match_stats_update_policy')
    drop_policy(:player_match_stats, 'player_match_stats_delete_policy')

    drop_policy(:champion_pools, 'champion_pools_select_policy')
    drop_policy(:champion_pools, 'champion_pools_insert_policy')
    drop_policy(:champion_pools, 'champion_pools_update_policy')
    drop_policy(:champion_pools, 'champion_pools_delete_policy')

    drop_policy(:scouting_targets, 'scouting_targets_select_policy')
    drop_policy(:scouting_targets, 'scouting_targets_insert_policy')
    drop_policy(:scouting_targets, 'scouting_targets_update_policy')
    drop_policy(:scouting_targets, 'scouting_targets_delete_policy')

    drop_policy(:schedules, 'schedules_select_policy')
    drop_policy(:schedules, 'schedules_insert_policy')
    drop_policy(:schedules, 'schedules_update_policy')
    drop_policy(:schedules, 'schedules_delete_policy')

    drop_policy(:vod_reviews, 'vod_reviews_select_policy')
    drop_policy(:vod_reviews, 'vod_reviews_insert_policy')
    drop_policy(:vod_reviews, 'vod_reviews_update_policy')
    drop_policy(:vod_reviews, 'vod_reviews_delete_policy')

    drop_policy(:vod_timestamps, 'vod_timestamps_select_policy')
    drop_policy(:vod_timestamps, 'vod_timestamps_insert_policy')
    drop_policy(:vod_timestamps, 'vod_timestamps_update_policy')
    drop_policy(:vod_timestamps, 'vod_timestamps_delete_policy')

    drop_policy(:team_goals, 'team_goals_select_policy')
    drop_policy(:team_goals, 'team_goals_insert_policy')
    drop_policy(:team_goals, 'team_goals_update_policy')
    drop_policy(:team_goals, 'team_goals_delete_policy')

    drop_policy(:audit_logs, 'audit_logs_select_policy')
    drop_policy(:audit_logs, 'audit_logs_insert_policy')

    drop_policy(:scrims, 'scrims_select_policy')
    drop_policy(:scrims, 'scrims_insert_policy')
    drop_policy(:scrims, 'scrims_update_policy')
    drop_policy(:scrims, 'scrims_delete_policy')

    drop_policy(:competitive_matches, 'competitive_matches_select_policy')
    drop_policy(:competitive_matches, 'competitive_matches_insert_policy')
    drop_policy(:competitive_matches, 'competitive_matches_update_policy')
    drop_policy(:competitive_matches, 'competitive_matches_delete_policy')

    # Drop functions
    execute 'DROP FUNCTION IF EXISTS public.user_organization_id();'
    execute 'DROP FUNCTION IF EXISTS public.current_user_id();'
    execute 'DROP FUNCTION IF EXISTS public.is_admin();'

    # Disable RLS
    disable_rls_on_table(:users)
    disable_rls_on_table(:players)
    disable_rls_on_table(:matches)
    disable_rls_on_table(:player_match_stats)
    disable_rls_on_table(:champion_pools)
    disable_rls_on_table(:scouting_targets)
    disable_rls_on_table(:schedules)
    disable_rls_on_table(:vod_reviews)
    disable_rls_on_table(:vod_timestamps)
    disable_rls_on_table(:team_goals)
    disable_rls_on_table(:audit_logs)
    disable_rls_on_table(:scrims)
    disable_rls_on_table(:competitive_matches)
  end

  private

  def enable_rls_on_table(table_name)
    execute "ALTER TABLE #{table_name} ENABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE #{table_name} FORCE ROW LEVEL SECURITY;"
  end

  def disable_rls_on_table(table_name)
    execute "ALTER TABLE #{table_name} DISABLE ROW LEVEL SECURITY;"
  end

  def create_policy(table_name, operation, policy_name, condition)
    operation_sql = operation.to_s.upcase
    using_or_check = [:insert].include?(operation) ? 'WITH CHECK' : 'USING'
    
    execute <<-SQL
      CREATE POLICY #{policy_name} ON #{table_name}
      FOR #{operation_sql}
      #{using_or_check} (#{condition});
    SQL
  end

  def drop_policy(table_name, policy_name)
    execute "DROP POLICY IF EXISTS #{policy_name} ON #{table_name};"
  end
end
