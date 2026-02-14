# frozen_string_literal: true

# Concern to prevent N+1 queries when loading primary key information
# Original issue: 5,785 individual queries totaling 21s
module PrimaryKeyBatchLoader
  extend ActiveSupport::Concern

  class_methods do
    # Batch load primary keys for multiple tables at once
    # Instead of 5,785 individual queries, this does 1 query
    def batch_load_primary_keys(table_oids)
      return {} if table_oids.blank?

      sql = <<~SQL
        SELECT
          i.indrelid::regclass::text as table_name,
          i.indrelid as table_oid,
          array_agg(a.attname ORDER BY array_position(i.indkey, a.attnum)) as primary_key_columns
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = ANY($1)
          AND i.indisprimary
        GROUP BY i.indrelid
      SQL

      result = ActiveRecord::Base.connection.exec_query(
        sql,
        'SQL',
        [table_oids]
      )

      result.each_with_object({}) do |row, hash|
        hash[row['table_oid']] = {
          table_name: row['table_name'],
          columns: row['primary_key_columns']
        }
      end
    end

    # Cache primary keys in memory for the duration of the request (thread-safe)
    def cached_primary_keys_for(table_oid)
      Thread.current[:pk_cache] ||= {}

      unless Thread.current[:pk_cache].key?(table_oid)
        Thread.current[:pk_cache].merge!(batch_load_primary_keys([table_oid]))
      end

      Thread.current[:pk_cache][table_oid]
    end

    # Preload primary keys for all tables in given schemas
    def preload_schema_primary_keys(schema_names = ['public'])
      sql = <<~SQL
        SELECT DISTINCT i.indrelid as table_oid
        FROM pg_index i
        JOIN pg_class c ON c.oid = i.indrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = ANY($1)
          AND i.indisprimary
      SQL

      result = ActiveRecord::Base.connection.exec_query(sql, 'SQL', [schema_names])
      table_oids = result.rows.flatten

      Thread.current[:pk_cache] = batch_load_primary_keys(table_oids)

      Rails.logger.info "Preloaded primary keys for #{Thread.current[:pk_cache].size} tables"
      Thread.current[:pk_cache]
    end
  end

  included do
    # Instance method to get primary key without query
    def primary_key_columns_cached
      table_oid = fetch_table_oid
      self.class.cached_primary_keys_for(table_oid)&.dig(:columns) || [self.class.primary_key]
    end

    private

    # Get table OID for current model
    def fetch_table_oid
      # Cache in class variable to avoid repeated queries
      self.class.instance_variable_get(:@_table_oid) ||
        self.class.instance_variable_set(:@_table_oid, begin
          sql = "SELECT $1::regclass::oid"
          result = ActiveRecord::Base.connection.exec_query(sql, 'SQL', [self.class.table_name])
          result.rows.first&.first
        end)
    end
  end
end
