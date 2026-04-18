# frozen_string_literal: true

class FixSchemaMigrationsRls < ActiveRecord::Migration[7.2]
  def up
    execute "DROP POLICY IF EXISTS schema_migrations_deny_all ON schema_migrations;"
    execute "DROP POLICY IF EXISTS ar_internal_metadata_deny_all ON ar_internal_metadata;"
    execute "ALTER TABLE schema_migrations DISABLE ROW LEVEL SECURITY;" rescue nil
    execute "ALTER TABLE ar_internal_metadata DISABLE ROW LEVEL SECURITY;" rescue nil
  end

  def down; end
end
