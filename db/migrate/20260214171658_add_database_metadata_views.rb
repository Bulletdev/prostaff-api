# frozen_string_literal: true

class AddDatabaseMetadataViews < ActiveRecord::Migration[7.2]
  def up
    # Materialized view for table privileges (72s query, 20% of total time)
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS mv_table_privileges AS
      SELECT
        c.oid::int8 as relation_id,
        nc.nspname as schema,
        c.relname as name,
        CASE
          WHEN c.relkind = 'r' THEN 'table'
          WHEN c.relkind = 'v' THEN 'view'
          WHEN c.relkind = 'm' THEN 'materialized_view'
          WHEN c.relkind = 'f' THEN 'foreign_table'
          WHEN c.relkind = 'p' THEN 'partitioned_table'
        END as kind,
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'grantor', grantor.rolname,
              'grantee', grantee.rolname,
              'privilege_type', _priv.privilege_type,
              'is_grantable', _priv.is_grantable
            )
          ) filter (where _priv is not null),
          '[]'::jsonb
        ) as privileges,
        now() as refreshed_at
      FROM pg_class c
      JOIN pg_namespace as nc ON nc.oid = c.relnamespace
      LEFT JOIN LATERAL (
        SELECT grantor, grantee, privilege_type, is_grantable
        FROM aclexplode(coalesce(c.relacl, acldefault('r', c.relowner)))
      ) as _priv ON true
      LEFT JOIN pg_roles as grantor ON grantor.oid = _priv.grantor
      LEFT JOIN (
        SELECT
          pg_roles.oid,
          pg_roles.rolname
        FROM pg_roles
        UNION ALL
        SELECT
          0::oid as oid, 'PUBLIC'
      ) as grantee ON grantee.oid = _priv.grantee
      WHERE c.relkind IN ('r', 'v', 'm', 'f', 'p')
        AND NOT pg_is_other_temp_schema(nc.oid)
        AND nc.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
      GROUP BY
        c.oid,
        nc.nspname,
        c.relname,
        c.relkind
      WITH DATA;

      CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_table_privileges_pkey
        ON mv_table_privileges (relation_id);

      CREATE INDEX IF NOT EXISTS idx_mv_table_privileges_schema
        ON mv_table_privileges (schema);
    SQL

    # Materialized view for available extensions (59s query, 16.6% of total time)
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS mv_available_extensions AS
      SELECT
        e.name,
        n.nspname AS schema,
        e.default_version,
        x.extversion AS installed_version,
        e.comment,
        now() as refreshed_at
      FROM
        pg_available_extensions() e(name, default_version, comment)
        LEFT JOIN pg_extension x ON e.name = x.extname
        LEFT JOIN pg_namespace n ON x.extnamespace = n.oid
      WITH DATA;

      CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_extensions_pkey
        ON mv_available_extensions (name);
    SQL

    # Materialized view for timezone names (14.5s query, 37 calls, 44k rows)
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS mv_timezone_names AS
      SELECT name, now() as refreshed_at
      FROM pg_timezone_names
      ORDER BY name
      WITH DATA;

      CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_timezone_names_pkey
        ON mv_timezone_names (name);
    SQL

    # Materialized view for RLS policies (6.2s query)
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS mv_rls_policies AS
      SELECT
        pol.oid::int8 AS id,
        n.nspname AS schema,
        c.relname AS table_name,
        c.oid::int8 AS table_id,
        pol.polname AS name,
        CASE
          WHEN pol.polpermissive THEN 'PERMISSIVE'
          ELSE 'RESTRICTIVE'
        END AS action,
        array_to_json(
          CASE
            WHEN pol.polroles = '{0}'::oid[] THEN ARRAY['PUBLIC']::text[]
            ELSE ARRAY(
              SELECT pg_roles.rolname
              FROM pg_roles
              WHERE pg_roles.oid = ANY(pol.polroles)
              ORDER BY pg_roles.rolname
            )
          END
        ) AS roles,
        CASE pol.polcmd
          WHEN 'r' THEN 'SELECT'
          WHEN 'a' THEN 'INSERT'
          WHEN 'w' THEN 'UPDATE'
          WHEN 'd' THEN 'DELETE'
          WHEN '*' THEN 'ALL'
          ELSE 'UNKNOWN'
        END AS command,
        pg_get_expr(pol.polqual, pol.polrelid) AS definition,
        pg_get_expr(pol.polwithcheck, pol.polrelid) AS check_expression,
        now() as refreshed_at
      FROM
        pg_policy pol
        JOIN pg_class c ON c.oid = pol.polrelid
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE
        n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
      GROUP BY
        pol.oid,
        n.nspname,
        c.relname,
        c.oid,
        pol.polname,
        pol.polpermissive,
        pol.polroles,
        pol.polcmd,
        pol.polqual,
        pol.polwithcheck;

      CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_rls_policies_pkey
        ON mv_rls_policies (id);

      CREATE INDEX IF NOT EXISTS idx_mv_rls_policies_schema_table
        ON mv_rls_policies (schema, table_name);
    SQL

    # Function to refresh all metadata views
    execute <<~SQL
      CREATE OR REPLACE FUNCTION refresh_database_metadata_views()
      RETURNS void
      LANGUAGE plpgsql
      AS $$
      BEGIN
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_table_privileges;
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_available_extensions;
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_timezone_names;
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rls_policies;

        RAISE NOTICE 'All database metadata views refreshed at %', now();
      END;
      $$;
    SQL

    # Add comments
    execute <<~SQL
      COMMENT ON MATERIALIZED VIEW mv_table_privileges IS
        'Cached table privileges to reduce expensive dashboard queries (was 72s/20% of query time)';
      COMMENT ON MATERIALIZED VIEW mv_available_extensions IS
        'Cached extension information (was 59s/16.6% of query time)';
      COMMENT ON MATERIALIZED VIEW mv_timezone_names IS
        'Cached timezone names (was 14.5s, 37 calls with 0% cache hit rate)';
      COMMENT ON MATERIALIZED VIEW mv_rls_policies IS
        'Cached RLS policies (was 6.2s of query time)';
      COMMENT ON FUNCTION refresh_database_metadata_views() IS
        'Refresh all database metadata materialized views. Run after schema changes.';
    SQL
  end

  def down
    execute 'DROP FUNCTION IF EXISTS refresh_database_metadata_views();'
    execute 'DROP MATERIALIZED VIEW IF EXISTS mv_rls_policies;'
    execute 'DROP MATERIALIZED VIEW IF EXISTS mv_timezone_names;'
    execute 'DROP MATERIALIZED VIEW IF EXISTS mv_available_extensions;'
    execute 'DROP MATERIALIZED VIEW IF EXISTS mv_table_privileges;'
  end
end
