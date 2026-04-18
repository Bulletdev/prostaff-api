# frozen_string_literal: true

# Rails internal tables (schema_migrations, ar_internal_metadata) should never
# have RLS. With FORCE ROW LEVEL SECURITY and a deny-all policy, db:migrate
# fails on every deploy because the prostaff user cannot INSERT into
# schema_migrations to record completed migrations. This migration undoes the
# RLS applied by EnableRlsOnRemainingTables (20260125000001).
class RemoveRlsFromRailsInternalTables < ActiveRecord::Migration[7.2]
  def up
    execute "DROP POLICY IF EXISTS schema_migrations_deny_all ON schema_migrations;"
    execute "ALTER TABLE schema_migrations NO FORCE ROW LEVEL SECURITY;"
    execute "ALTER TABLE schema_migrations DISABLE ROW LEVEL SECURITY;"

    execute "DROP POLICY IF EXISTS ar_internal_metadata_deny_all ON ar_internal_metadata;"
    execute "ALTER TABLE ar_internal_metadata NO FORCE ROW LEVEL SECURITY;"
    execute "ALTER TABLE ar_internal_metadata DISABLE ROW LEVEL SECURITY;"
  end

  def down
    execute "ALTER TABLE schema_migrations ENABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE schema_migrations FORCE ROW LEVEL SECURITY;"
    execute <<-SQL
      CREATE POLICY schema_migrations_deny_all ON schema_migrations
      FOR ALL USING (false);
    SQL

    execute "ALTER TABLE ar_internal_metadata ENABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE ar_internal_metadata FORCE ROW LEVEL SECURITY;"
    execute <<-SQL
      CREATE POLICY ar_internal_metadata_deny_all ON ar_internal_metadata
      FOR ALL USING (false);
    SQL
  end
end
