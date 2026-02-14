# frozen_string_literal: true

# Service to cache expensive database metadata queries
# Reduces load from database dashboard and other metadata-heavy operations
class DatabaseMetadataCacheService
  CACHE_PREFIX = 'db_meta'
  DEFAULT_TTL = 15.minutes # Metadata doesn't change often

  class << self
    # Cache table privileges query (72s total, 20% of query time)
    def table_privileges(schema: nil, force_refresh: false)
      cache_key = "#{CACHE_PREFIX}:table_privileges:#{schema || 'all'}"

      fetch_with_cache(cache_key, ttl: 15.minutes, force: force_refresh) do
        execute_table_privileges_query(schema)
      end
    end

    # Cache available extensions query (59s total, 16.6% of query time)
    def available_extensions(force_refresh: false)
      cache_key = "#{CACHE_PREFIX}:extensions"

      fetch_with_cache(cache_key, ttl: 30.minutes, force: force_refresh) do
        execute_extensions_query
      end
    end

    # Cache pg_type metadata (13.8s total with high call volume)
    def pg_types(type_names: nil, force_refresh: false)
      cache_key = "#{CACHE_PREFIX}:pg_types:#{Array(type_names).sort.join(',')}"

      fetch_with_cache(cache_key, ttl: 1.hour, force: force_refresh) do
        execute_pg_types_query(type_names)
      end
    end

    # Cache table metadata with columns (complex query with multiple CTEs)
    def table_metadata(schema:, table_name:, force_refresh: false)
      cache_key = "#{CACHE_PREFIX}:table_meta:#{schema}:#{table_name}"

      fetch_with_cache(cache_key, ttl: 10.minutes, force: force_refresh) do
        execute_table_metadata_query(schema, table_name)
      end
    end

    # Cache policies metadata
    def policies(schema: nil, force_refresh: false)
      cache_key = "#{CACHE_PREFIX}:policies:#{schema || 'all'}"

      fetch_with_cache(cache_key, ttl: 30.minutes, force: force_refresh) do
        execute_policies_query(schema)
      end
    end

    # Cache pg_attribute metadata (5,930 calls, 7s total)
    # Used by ActiveRecord for schema introspection
    def table_columns(table_name:, force_refresh: false)
      cache_key = "#{CACHE_PREFIX}:columns:#{table_name}"

      fetch_with_cache(cache_key, ttl: 1.hour, force: force_refresh) do
        execute_table_columns_query(table_name)
      end
    end

    # Cache timezone names (37 calls, 14.5s total, 0% cache hit)
    def timezone_names(force_refresh: false)
      cache_key = "#{CACHE_PREFIX}:timezones"

      fetch_with_cache(cache_key, ttl: 24.hours, force: force_refresh) do
        execute_timezone_names_query
      end
    end

    # Invalidate all metadata cache (call after migrations or schema changes)
    def invalidate_all!
      return unless redis_available?

      total_deleted = 0
      cursor = '0'

      # Use SCAN instead of KEYS to avoid blocking Redis
      loop do
        cursor, keys = Rails.cache.redis.scan(cursor, match: "#{CACHE_PREFIX}:*", count: 100)
        if keys.any?
          Rails.cache.redis.del(*keys)
          total_deleted += keys.size
        end
        break if cursor == '0'
      end

      Rails.logger.info "Invalidated #{total_deleted} database metadata cache entries"
    end

    # Invalidate specific table cache
    def invalidate_table!(schema:, table_name:)
      return unless redis_available?

      total_deleted = 0
      cursor = '0'
      pattern = "#{CACHE_PREFIX}:*:#{schema}:#{table_name}"

      # Use SCAN instead of KEYS
      loop do
        cursor, keys = Rails.cache.redis.scan(cursor, match: pattern, count: 100)
        if keys.any?
          Rails.cache.redis.del(*keys)
          total_deleted += keys.size
        end
        break if cursor == '0'
      end

      Rails.logger.info "Invalidated #{total_deleted} cache entries for #{schema}.#{table_name}"
    end

    private

    def fetch_with_cache(key, ttl:, force: false)
      return yield unless redis_available?

      if force
        Rails.cache.delete(key)
        result = yield
        Rails.cache.write(key, result, expires_in: ttl)
        return result
      end

      Rails.cache.fetch(key, expires_in: ttl) { yield }
    end

    def redis_available?
      # Thread-safe check
      Thread.current[:dmcs_redis_available] ||= begin
        Rails.cache.respond_to?(:redis) && Rails.cache.redis.ping == 'PONG'
      rescue
        false
      end
    end

    def execute_table_privileges_query(schema)
      if schema
        schema_filter = "AND nc.nspname = $1"
        bind_params = [schema]
      else
        schema_filter = "AND nc.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')"
        bind_params = []
      end

      sql = <<~SQL
        SELECT
          c.oid as relation_id,
          nc.nspname as schema,
          c.relname as name,
          c.relkind as kind,
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
          ) as privileges
        FROM pg_class c
        JOIN pg_namespace as nc ON nc.oid = c.relnamespace
        LEFT JOIN LATERAL (
          SELECT grantor, grantee, privilege_type, is_grantable
          FROM aclexplode(coalesce(c.relacl, acldefault('r', c.relowner)))
        ) as _priv ON true
        LEFT JOIN pg_roles as grantor ON grantor.oid = _priv.grantor
        LEFT JOIN pg_roles as grantee ON grantee.oid = _priv.grantee
        WHERE c.relkind IN ('r', 'v', 'm', 'f', 'p')
          #{schema_filter}
        GROUP BY c.oid, nc.nspname, c.relname, c.relkind
      SQL

      ActiveRecord::Base.connection.exec_query(sql, 'SQL', bind_params).to_a
    end

    def execute_extensions_query
      sql = <<~SQL
        SELECT
          e.name,
          n.nspname AS schema,
          e.default_version,
          x.extversion AS installed_version,
          e.comment
        FROM
          pg_available_extensions() e(name, default_version, comment)
          LEFT JOIN pg_extension x ON e.name = x.extname
          LEFT JOIN pg_namespace n ON x.extnamespace = n.oid
      SQL

      ActiveRecord::Base.connection.execute(sql).to_a
    end

    def execute_pg_types_query(type_names)
      type_names = Array(type_names).presence || %w[
        uuid text varchar int4 int8 bool timestamp timestamptz
        jsonb json numeric float4 float8 date interval
      ]

      placeholders = type_names.map.with_index { |_, i| "$#{i + 1}" }.join(', ')

      sql = <<~SQL
        SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, r.rngsubtype, t.typtype, t.typbasetype
        FROM pg_type as t
        LEFT JOIN pg_range as r ON oid = rngtypid
        WHERE t.typname IN (#{placeholders})
      SQL

      ActiveRecord::Base.connection.exec_query(sql, 'SQL', type_names).to_a
    end

    def execute_table_metadata_query(schema, table_name)
      # This is a simplified version - adjust based on actual needs
      sql = <<~SQL
        SELECT
          c.oid::int8 AS id,
          nc.nspname AS schema,
          c.relname AS name,
          c.relrowsecurity AS rls_enabled,
          obj_description(c.oid) AS comment
        FROM pg_class c
        JOIN pg_namespace nc ON nc.oid = c.relnamespace
        WHERE nc.nspname = $1 AND c.relname = $2
      SQL

      ActiveRecord::Base.connection.exec_query(sql, 'SQL', [schema, table_name]).to_a
    end

    def execute_policies_query(schema)
      if schema
        schema_filter = "AND n.nspname = $1"
        bind_params = [schema]
      else
        schema_filter = "AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')"
        bind_params = []
      end

      sql = <<~SQL
        SELECT
          pol.oid::int8 AS id,
          n.nspname AS schema,
          c.relname AS table,
          pol.polname AS name,
          CASE WHEN pol.polpermissive THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END AS action,
          pg_get_expr(pol.polqual, pol.polrelid) AS definition
        FROM pg_policy pol
        JOIN pg_class c ON c.oid = pol.polrelid
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE true
          #{schema_filter}
      SQL

      ActiveRecord::Base.connection.exec_query(sql, 'SQL', bind_params).to_a
    end

    def execute_table_columns_query(table_name)
      sql = <<~SQL
        SELECT
          a.attname,
          format_type(a.atttypid, a.atttypmod) as formatted_type,
          pg_get_expr(d.adbin, d.adrelid) as default_expr,
          a.attnotnull,
          a.atttypid,
          a.atttypmod,
          c.collname,
          col_description(a.attrelid, a.attnum) AS comment,
          a.attidentity AS identity,
          a.attgenerated as attgenerated
        FROM pg_attribute a
        LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
        LEFT JOIN pg_type t ON a.atttypid = t.oid
        LEFT JOIN pg_collation c ON a.attcollation = c.oid AND a.attcollation <> t.typcollation
        WHERE a.attrelid = $1::regclass
          AND a.attnum > 0
          AND NOT a.attisdropped
        ORDER BY a.attnum
      SQL

      ActiveRecord::Base.connection.exec_query(sql, 'SQL', [table_name]).to_a
    end

    def execute_timezone_names_query
      # Try to use materialized view first, fall back to direct query
      sql = if materialized_view_exists?('mv_timezone_names')
              'SELECT name FROM mv_timezone_names ORDER BY name'
            else
              'SELECT name FROM pg_timezone_names ORDER BY name'
            end

      ActiveRecord::Base.connection.execute(sql).to_a
    end

    def materialized_view_exists?(view_name)
      sql = "SELECT 1 FROM pg_matviews WHERE matviewname = $1"
      ActiveRecord::Base.connection.exec_query(sql, 'SQL', [view_name]).any?
    rescue
      false
    end
  end
end
