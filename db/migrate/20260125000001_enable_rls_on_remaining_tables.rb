# frozen_string_literal: true

class EnableRlsOnRemainingTables < ActiveRecord::Migration[7.2]
  def up
    # Enable RLS on organization-scoped tables
    enable_rls_on_table(:support_tickets)
    enable_rls_on_table(:support_ticket_messages)
    enable_rls_on_table(:draft_plans)
    enable_rls_on_table(:tactical_boards)

    # Enable RLS on authentication tables
    enable_rls_on_table(:password_reset_tokens)
    enable_rls_on_table(:token_blacklists)

    # Enable RLS on shared resources
    enable_rls_on_table(:opponent_teams)
    enable_rls_on_table(:support_faqs)
    enable_rls_on_table(:organizations)

    # Enable RLS on Rails internal tables (block all API access)
    enable_rls_on_table(:ar_internal_metadata)
    enable_rls_on_table(:schema_migrations)

    # ===========================================================================
    # SUPPORT TICKETS - Organization scoped
    # ===========================================================================
    create_policy(:support_tickets, :select, 'support_tickets_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:support_tickets, :insert, 'support_tickets_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:support_tickets, :update, 'support_tickets_update_policy',
      'organization_id = public.user_organization_id() AND (public.is_admin() OR user_id = public.current_user_id())')
    create_policy(:support_tickets, :delete, 'support_tickets_delete_policy',
      'organization_id = public.user_organization_id() AND public.is_admin()')

    # ===========================================================================
    # SUPPORT TICKET MESSAGES - Scoped via support_tickets relationship
    # ===========================================================================
    execute <<-SQL
      CREATE POLICY support_ticket_messages_select_policy ON support_ticket_messages
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM support_tickets
          WHERE support_tickets.id = support_ticket_messages.support_ticket_id
          AND support_tickets.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY support_ticket_messages_insert_policy ON support_ticket_messages
      FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM support_tickets
          WHERE support_tickets.id = support_ticket_messages.support_ticket_id
          AND support_tickets.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY support_ticket_messages_update_policy ON support_ticket_messages
      FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM support_tickets
          WHERE support_tickets.id = support_ticket_messages.support_ticket_id
          AND support_tickets.organization_id = public.user_organization_id()
        )
        AND public.is_admin()
      );
    SQL

    execute <<-SQL
      CREATE POLICY support_ticket_messages_delete_policy ON support_ticket_messages
      FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM support_tickets
          WHERE support_tickets.id = support_ticket_messages.support_ticket_id
          AND support_tickets.organization_id = public.user_organization_id()
        )
        AND public.is_admin()
      );
    SQL

    # ===========================================================================
    # DRAFT PLANS - Organization scoped
    # ===========================================================================
    create_policy(:draft_plans, :select, 'draft_plans_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:draft_plans, :insert, 'draft_plans_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:draft_plans, :update, 'draft_plans_update_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:draft_plans, :delete, 'draft_plans_delete_policy',
      'organization_id = public.user_organization_id()')

    # ===========================================================================
    # TACTICAL BOARDS - Organization scoped
    # ===========================================================================
    create_policy(:tactical_boards, :select, 'tactical_boards_select_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:tactical_boards, :insert, 'tactical_boards_insert_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:tactical_boards, :update, 'tactical_boards_update_policy',
      'organization_id = public.user_organization_id()')
    create_policy(:tactical_boards, :delete, 'tactical_boards_delete_policy',
      'organization_id = public.user_organization_id()')

    # ===========================================================================
    # PASSWORD RESET TOKENS - Scoped via user relationship
    # Users can only see their own password reset tokens
    # ===========================================================================
    execute <<-SQL
      CREATE POLICY password_reset_tokens_select_policy ON password_reset_tokens
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM users
          WHERE users.id = password_reset_tokens.user_id
          AND users.id = public.current_user_id()
        )
      );
    SQL

    # Only system can insert password reset tokens (no user-facing INSERT policy)
    # This prevents direct inserts via API while allowing application code to insert
    execute <<-SQL
      CREATE POLICY password_reset_tokens_insert_policy ON password_reset_tokens
      FOR INSERT
      WITH CHECK (false);
    SQL

    execute <<-SQL
      CREATE POLICY password_reset_tokens_update_policy ON password_reset_tokens
      FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM users
          WHERE users.id = password_reset_tokens.user_id
          AND users.id = public.current_user_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY password_reset_tokens_delete_policy ON password_reset_tokens
      FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM users
          WHERE users.id = password_reset_tokens.user_id
          AND users.id = public.current_user_id()
        )
      );
    SQL

    # ===========================================================================
    # TOKEN BLACKLISTS - Global table for JWT revocation
    # Anyone authenticated can read (to check if token is blacklisted)
    # Only system can write (no user-facing INSERT/UPDATE/DELETE)
    # ===========================================================================
    execute <<-SQL
      CREATE POLICY token_blacklists_select_policy ON token_blacklists
      FOR SELECT
      USING (public.current_user_id() IS NOT NULL);
    SQL

    # Prevent direct modifications via API
    execute <<-SQL
      CREATE POLICY token_blacklists_insert_policy ON token_blacklists
      FOR INSERT
      WITH CHECK (false);
    SQL

    execute <<-SQL
      CREATE POLICY token_blacklists_update_policy ON token_blacklists
      FOR UPDATE
      USING (false);
    SQL

    execute <<-SQL
      CREATE POLICY token_blacklists_delete_policy ON token_blacklists
      FOR DELETE
      USING (false);
    SQL

    # ===========================================================================
    # OPPONENT TEAMS - Shared resource
    # Users can see opponent teams they've played against via scrims
    # ===========================================================================
    execute <<-SQL
      CREATE POLICY opponent_teams_select_policy ON opponent_teams
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM scrims
          WHERE scrims.opponent_team_id = opponent_teams.id
          AND scrims.organization_id = public.user_organization_id()
        )
        OR
        EXISTS (
          SELECT 1 FROM competitive_matches
          WHERE competitive_matches.opponent_team_id = opponent_teams.id
          AND competitive_matches.organization_id = public.user_organization_id()
        )
      );
    SQL

    create_policy(:opponent_teams, :insert, 'opponent_teams_insert_policy',
      'public.user_organization_id() IS NOT NULL')

    execute <<-SQL
      CREATE POLICY opponent_teams_update_policy ON opponent_teams
      FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM scrims
          WHERE scrims.opponent_team_id = opponent_teams.id
          AND scrims.organization_id = public.user_organization_id()
        )
      );
    SQL

    execute <<-SQL
      CREATE POLICY opponent_teams_delete_policy ON opponent_teams
      FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM scrims
          WHERE scrims.opponent_team_id = opponent_teams.id
          AND scrims.organization_id = public.user_organization_id()
        )
        AND public.is_admin()
      );
    SQL

    # ===========================================================================
    # SUPPORT FAQs - Public knowledge base
    # Everyone can read published FAQs
    # Only admins can modify
    # ===========================================================================
    execute <<-SQL
      CREATE POLICY support_faqs_select_policy ON support_faqs
      FOR SELECT
      USING (published = true OR public.is_admin());
    SQL

    execute <<-SQL
      CREATE POLICY support_faqs_insert_policy ON support_faqs
      FOR INSERT
      WITH CHECK (public.is_admin());
    SQL

    execute <<-SQL
      CREATE POLICY support_faqs_update_policy ON support_faqs
      FOR UPDATE
      USING (public.is_admin());
    SQL

    execute <<-SQL
      CREATE POLICY support_faqs_delete_policy ON support_faqs
      FOR DELETE
      USING (public.is_admin());
    SQL

    # ===========================================================================
    # ORGANIZATIONS - Users can only see their own organization
    # ===========================================================================
    execute <<-SQL
      CREATE POLICY organizations_select_policy ON organizations
      FOR SELECT
      USING (id = public.user_organization_id());
    SQL

    # Only super admins should create organizations (block via API)
    execute <<-SQL
      CREATE POLICY organizations_insert_policy ON organizations
      FOR INSERT
      WITH CHECK (false);
    SQL

    execute <<-SQL
      CREATE POLICY organizations_update_policy ON organizations
      FOR UPDATE
      USING (id = public.user_organization_id() AND public.is_admin());
    SQL

    # Prevent organization deletion via API
    execute <<-SQL
      CREATE POLICY organizations_delete_policy ON organizations
      FOR DELETE
      USING (false);
    SQL

    # ===========================================================================
    # RAILS INTERNAL TABLES - Block all API access
    # These should never be accessible via PostgREST/API
    # ===========================================================================

    # ar_internal_metadata - Rails internal
    execute <<-SQL
      CREATE POLICY ar_internal_metadata_deny_all ON ar_internal_metadata
      FOR ALL
      USING (false);
    SQL

    # schema_migrations - Rails internal
    execute <<-SQL
      CREATE POLICY schema_migrations_deny_all ON schema_migrations
      FOR ALL
      USING (false);
    SQL
  end

  def down
    # Drop policies for support_tickets
    drop_policy(:support_tickets, 'support_tickets_select_policy')
    drop_policy(:support_tickets, 'support_tickets_insert_policy')
    drop_policy(:support_tickets, 'support_tickets_update_policy')
    drop_policy(:support_tickets, 'support_tickets_delete_policy')

    # Drop policies for support_ticket_messages
    drop_policy(:support_ticket_messages, 'support_ticket_messages_select_policy')
    drop_policy(:support_ticket_messages, 'support_ticket_messages_insert_policy')
    drop_policy(:support_ticket_messages, 'support_ticket_messages_update_policy')
    drop_policy(:support_ticket_messages, 'support_ticket_messages_delete_policy')

    # Drop policies for draft_plans
    drop_policy(:draft_plans, 'draft_plans_select_policy')
    drop_policy(:draft_plans, 'draft_plans_insert_policy')
    drop_policy(:draft_plans, 'draft_plans_update_policy')
    drop_policy(:draft_plans, 'draft_plans_delete_policy')

    # Drop policies for tactical_boards
    drop_policy(:tactical_boards, 'tactical_boards_select_policy')
    drop_policy(:tactical_boards, 'tactical_boards_insert_policy')
    drop_policy(:tactical_boards, 'tactical_boards_update_policy')
    drop_policy(:tactical_boards, 'tactical_boards_delete_policy')

    # Drop policies for password_reset_tokens
    drop_policy(:password_reset_tokens, 'password_reset_tokens_select_policy')
    drop_policy(:password_reset_tokens, 'password_reset_tokens_insert_policy')
    drop_policy(:password_reset_tokens, 'password_reset_tokens_update_policy')
    drop_policy(:password_reset_tokens, 'password_reset_tokens_delete_policy')

    # Drop policies for token_blacklists
    drop_policy(:token_blacklists, 'token_blacklists_select_policy')
    drop_policy(:token_blacklists, 'token_blacklists_insert_policy')
    drop_policy(:token_blacklists, 'token_blacklists_update_policy')
    drop_policy(:token_blacklists, 'token_blacklists_delete_policy')

    # Drop policies for opponent_teams
    drop_policy(:opponent_teams, 'opponent_teams_select_policy')
    drop_policy(:opponent_teams, 'opponent_teams_insert_policy')
    drop_policy(:opponent_teams, 'opponent_teams_update_policy')
    drop_policy(:opponent_teams, 'opponent_teams_delete_policy')

    # Drop policies for support_faqs
    drop_policy(:support_faqs, 'support_faqs_select_policy')
    drop_policy(:support_faqs, 'support_faqs_insert_policy')
    drop_policy(:support_faqs, 'support_faqs_update_policy')
    drop_policy(:support_faqs, 'support_faqs_delete_policy')

    # Drop policies for organizations
    drop_policy(:organizations, 'organizations_select_policy')
    drop_policy(:organizations, 'organizations_insert_policy')
    drop_policy(:organizations, 'organizations_update_policy')
    drop_policy(:organizations, 'organizations_delete_policy')

    # Drop policies for Rails internal tables
    drop_policy(:ar_internal_metadata, 'ar_internal_metadata_deny_all')
    drop_policy(:schema_migrations, 'schema_migrations_deny_all')

    # Disable RLS
    disable_rls_on_table(:support_tickets)
    disable_rls_on_table(:support_ticket_messages)
    disable_rls_on_table(:draft_plans)
    disable_rls_on_table(:tactical_boards)
    disable_rls_on_table(:password_reset_tokens)
    disable_rls_on_table(:token_blacklists)
    disable_rls_on_table(:opponent_teams)
    disable_rls_on_table(:support_faqs)
    disable_rls_on_table(:organizations)
    disable_rls_on_table(:ar_internal_metadata)
    disable_rls_on_table(:schema_migrations)
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
