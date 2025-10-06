namespace :db do
  desc "Mark all migrations as applied"
  task mark_migrations_up: :environment do
    versions = %w[
      20241001000002
      20241001000003
      20241001000004
      20241001000005
      20241001000006
      20241001000007
      20241001000008
      20241001000009
      20241001000010
      20241001000011
      20241001000012
      20241001000013
      20241001000014
    ]

    versions.each do |version|
      ActiveRecord::Base.connection.execute(
        "INSERT INTO schema_migrations (version) VALUES ('#{version}') ON CONFLICT DO NOTHING"
      )
    end

    puts "✅ All migrations marked as up!"
  end

  desc "Reset public schema tables"
  task reset_public_schema: :environment do
    puts "🗑️  Dropping all tables in public schema..."

    tables = ActiveRecord::Base.connection.execute(<<-SQL
      SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    SQL
    ).map { |row| row['tablename'] }

    tables.each do |table|
      next if table == 'schema_migrations' || table == 'ar_internal_metadata'

      puts "   Dropping #{table}..."
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{table} CASCADE")
    end

    # Clear schema_migrations
    ActiveRecord::Base.connection.execute("DELETE FROM schema_migrations")

    puts "✅ Public schema reset complete!"
  end
end
