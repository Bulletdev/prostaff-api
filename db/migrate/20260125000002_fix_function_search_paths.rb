# frozen_string_literal: true

class FixFunctionSearchPaths < ActiveRecord::Migration[7.2]
  def up
    # Fix user_organization_id function with secure search_path
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.user_organization_id()
      RETURNS uuid
      LANGUAGE sql
      STABLE
      SECURITY DEFINER
      SET search_path = public, pg_temp
      AS $$
        SELECT COALESCE(
          current_setting('app.current_organization_id', TRUE)::uuid,
          NULL
        );
      $$;
    SQL

    # Fix current_user_id function with secure search_path
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.current_user_id()
      RETURNS uuid
      LANGUAGE sql
      STABLE
      SECURITY DEFINER
      SET search_path = public, pg_temp
      AS $$
        SELECT COALESCE(
          current_setting('app.current_user_id', TRUE)::uuid,
          NULL
        );
      $$;
    SQL

    # Fix is_admin function with secure search_path
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.is_admin()
      RETURNS boolean
      LANGUAGE sql
      STABLE
      SECURITY DEFINER
      SET search_path = public, pg_temp
      AS $$
        SELECT COALESCE(
          current_setting('app.user_role', TRUE) = 'admin',
          FALSE
        );
      $$;
    SQL
  end

  def down
    # Revert to original functions without search_path
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
  end
end
