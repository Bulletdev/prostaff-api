# frozen_string_literal: true

# Security fix: revoke direct table access from Supabase anon role.
#
# Context:
#   ProStaff uses Supabase as PostgreSQL backend. Supabase exposes a REST API
#   (/rest/v1/) that maps directly to tables. Unauthenticated requests use the
#   `anon` role. The VITE_SUPABASE_PUBLISHABLE_KEY (anon key) is compiled into
#   the frontend JS bundle and is publicly visible.
#
#   Pentest finding (2026-04-14): GET /rest/v1/<table>?select=* with only the
#   anon key returned HTTP 200 + empty array on 9 tables. RLS was filtering rows
#   but the anon role still had SELECT privilege, confirming table existence and
#   allowing future exploitation if an RLS policy is ever misconfigured.
#
# Fix:
#   REVOKE ALL on each affected table from the anon role.
#   PostgREST will return 404 (table not in schema) instead of 200 + [].
#   Rails is unaffected — it connects as the postgres/service_role user,
#   not as anon.
#
# Tables that returned HTTP 200 in the pentest:
#   organizations, users, players, matches, player_match_stats,
#   audit_logs, messages, team_goals, vod_reviews
#
# Tables already returning 404 (no change needed):
#   scouting_notes, refresh_tokens, watchlists
class RevokeSupabaseAnonRoleAccess < ActiveRecord::Migration[7.1]
  # Tables that were accessible to the anon role
  TABLES = %w[
    organizations
    users
    players
    matches
    player_match_stats
    audit_logs
    messages
    team_goals
    vod_reviews
  ].freeze

  def up
    # Check if anon role exists before acting (local dev may not have it)
    return unless anon_role_exists?

    TABLES.each do |table|
      execute "REVOKE ALL ON TABLE #{table} FROM anon;"
    end

    Rails.logger.info "[Security] Revoked anon role access on #{TABLES.size} tables"
  end

  def down
    return unless anon_role_exists?

    # Restore minimum Supabase default grants
    # (SELECT only — Supabase default for anon role is read-only)
    TABLES.each do |table|
      execute "GRANT SELECT ON TABLE #{table} TO anon;"
    end
  end

  private

  def anon_role_exists?
    result = execute("SELECT 1 FROM pg_roles WHERE rolname = 'anon'")
    result.any?
  end
end
