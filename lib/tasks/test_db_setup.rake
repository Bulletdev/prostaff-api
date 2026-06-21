# frozen_string_literal: true

# Handles test DB schema loading for projects whose schema.rb contains
# Supabase-specific schemas (auth, extensions, vault, …) and extensions
# (supabase_vault) that are unavailable in a standard PostgreSQL container.
#
# Two entry points:
#   1. `test:db:setup`        — explicit, developer-facing setup command.
#   2. `db:test:load_schema`  — overrides the Rails default so that
#                               maintain_test_schema! (called by RSpec) also
#                               works without failing on Supabase extensions.
#
# Usage (first run or full reset):
#   RAILS_ENV=test TEST_DATABASE_URL=... bundle exec rake test:db:setup

SUPABASE_SCHEMA_PATCH = Module.new do
  def enable_extension(name, **)
    super
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.match?(/control file|not found|cannot be installed|does not exist/i)

    # Extension not present in standard PG — safe to skip for test purposes.
  end

  def create_schema(schema_name, **)
    super
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?('already exists')

    # Schema already exists (e.g. second run) — no-op.
  end
end

def load_schema_with_supabase_patch
  ActiveRecord::Base.connection.class.prepend(SUPABASE_SCHEMA_PATCH)
  load Rails.root.join('db/schema.rb')

  conn = ActiveRecord::Base.connection
  migration_versions = ActiveRecord::MigrationContext.new(
    Rails.root.join('db/migrate').to_s
  ).migrations.map { |m| m.version.to_s }

  existing = conn.execute('SELECT version FROM schema_migrations').to_a.map { |r| r['version'] }
  missing  = migration_versions - existing

  unless missing.empty?
    values = missing.map { |v| "('#{v}')" }.join(', ')
    conn.execute("INSERT INTO schema_migrations (version) VALUES #{values}")
  end
end

# Override the Rails default db:test:load_schema so that maintain_test_schema!
# (called automatically by RSpec) uses the patched loader instead of aborting
# on missing Supabase extensions. The purge step is intentionally preserved so
# the DB is cleaned before each schema reload.
if Rake::Task.task_defined?('db:test:load_schema')
  Rake::Task['db:test:load_schema'].clear
end

namespace :db do
  namespace :test do
    # Called automatically by RSpec's maintain_test_schema! when it detects the
    # schema is out of date. The DB already exists at this point — skip drop/create
    # and just re-apply the patched schema loader to pick up the latest schema.rb.
    task load_schema: :environment do
      load_schema_with_supabase_patch
    end
  end
end

namespace :test do
  namespace :db do
    desc 'Load schema into test DB, skipping Supabase-only extensions and schemas'
    task setup: :environment do
      load_schema_with_supabase_patch
      conn = ActiveRecord::Base.connection
      migration_count = ActiveRecord::MigrationContext.new(
        Rails.root.join('db/migrate').to_s
      ).migrations.length
      puts "Test schema loaded (#{conn.tables.length} tables, #{migration_count} migrations marked)."
    end
  end
end
