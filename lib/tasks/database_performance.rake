# frozen_string_literal: true

namespace :db do
  namespace :performance do
    desc 'Refresh all database metadata materialized views'
    task refresh_metadata: :environment do
      puts 'Refreshing database metadata views...'

      ActiveRecord::Base.connection.execute('SELECT refresh_database_metadata_views();')

      puts ' All metadata views refreshed'
    end

    desc 'Show query performance statistics from Redis cache'
    task query_stats: :environment do
      require 'terminal-table'

      unless Rails.cache.respond_to?(:redis)
        puts ' Redis not available - query stats not collected'
        exit 1
      end

      keys = Rails.cache.redis.keys('query_stats:*')

      if keys.empty?
        puts 'No query statistics available yet'
        exit 0
      end

      stats = keys.map do |key|
        data = Rails.cache.redis.hgetall(key)
        next if data.empty?

        {
          query: data['query']&.truncate(80),
          count: data['count'].to_i,
          total_time: data['total_time'].to_f.round(2),
          avg_time: (data['total_time'].to_f / data['count'].to_i).round(2),
          max_time: data['max_time'].to_f.round(2)
        }
      end.compact

      # Sort by total time descending
      stats.sort_by! { |s| -s[:total_time] }

      # Display top 20
      table = Terminal::Table.new do |t|
        t.title = 'Top Queries by Total Time (Last 24h)'
        t.headings = ['Query', 'Count', 'Total (ms)', 'Avg (ms)', 'Max (ms)']
        stats.first(20).each do |stat|
          t << [
            stat[:query],
            stat[:count],
            stat[:total_time],
            stat[:avg_time],
            stat[:max_time]
          ]
        end
      end

      puts table
      puts "\nTotal queries tracked: #{stats.size}"
      puts "Total execution time: #{stats.sum { |s| s[:total_time] }.round(2)}ms"
    end

    desc 'Clear query statistics cache'
    task clear_stats: :environment do
      unless Rails.cache.respond_to?(:redis)
        puts ' Redis not available'
        exit 1
      end

      keys = Rails.cache.redis.keys('query_stats:*')
      Rails.cache.redis.del(*keys) if keys.any?

      puts " Cleared #{keys.size} query statistics entries"
    end

    desc 'Analyze slow queries and provide recommendations'
    task analyze_slow_queries: :environment do
      unless Rails.cache.respond_to?(:redis)
        puts ' Redis not available - run query analysis on database instead'
        analyze_from_pg_stat_statements
        exit 0
      end

      keys = Rails.cache.redis.keys('query_stats:*')

      if keys.empty?
        puts 'No query statistics available - try analyzing from pg_stat_statements'
        analyze_from_pg_stat_statements
        exit 0
      end

      stats = keys.map do |key|
        data = Rails.cache.redis.hgetall(key)
        next if data.empty?

        {
          query: data['query'],
          count: data['count'].to_i,
          total_time: data['total_time'].to_f,
          avg_time: (data['total_time'].to_f / data['count'].to_i),
          max_time: data['max_time'].to_f
        }
      end.compact

      puts "\n=== SLOW QUERY ANALYSIS ===\n\n"

      # Queries with high average time
      slow_avg = stats.select { |s| s[:avg_time] > 100 }.sort_by { |s| -s[:avg_time] }
      if slow_avg.any?
        puts "  Queries with high average time (>100ms):\n"
        slow_avg.first(5).each do |s|
          puts "  • #{s[:avg_time].round(2)}ms avg - #{s[:query].truncate(100)}"
        end
        puts
      end

      # Queries with high total time
      high_total = stats.sort_by { |s| -s[:total_time] }.first(5)
      puts " Top queries by total execution time:\n"
      high_total.each do |s|
        puts "  • #{s[:total_time].round(2)}ms total (#{s[:count]} calls) - #{s[:query].truncate(100)}"
      end
      puts

      # High frequency queries
      high_freq = stats.select { |s| s[:count] > 100 }.sort_by { |s| -s[:count] }
      if high_freq.any?
        puts " High frequency queries (>100 calls):\n"
        high_freq.first(5).each do |s|
          puts "  • #{s[:count]} calls - #{s[:query].truncate(100)}"
        end
        puts
      end

      puts "\n=== RECOMMENDATIONS ===\n"
      puts "1. Review queries with >100ms average time for missing indexes"
      puts "2. Consider caching results for high-frequency queries"
      puts "3. Check if high total time queries can be batched or optimized"
      puts "4. Use EXPLAIN ANALYZE on slow queries to identify bottlenecks"
    end

    def analyze_from_pg_stat_statements
      puts "\nAttempting to use pg_stat_statements..."

      begin
        result = ActiveRecord::Base.connection.execute(<<~SQL)
          SELECT
            LEFT(query, 100) as query,
            calls,
            ROUND(total_exec_time::numeric, 2) as total_time_ms,
            ROUND(mean_exec_time::numeric, 2) as mean_time_ms,
            ROUND(max_exec_time::numeric, 2) as max_time_ms
          FROM pg_stat_statements
          WHERE query NOT LIKE '%pg_stat_statements%'
            AND query NOT LIKE '%SCHEMA%'
          ORDER BY total_exec_time DESC
          LIMIT 10;
        SQL

        require 'terminal-table'
        table = Terminal::Table.new do |t|
          t.title = 'Top Queries from pg_stat_statements'
          t.headings = ['Query', 'Calls', 'Total (ms)', 'Avg (ms)', 'Max (ms)']
          result.each do |row|
            t << [
              row['query'],
              row['calls'],
              row['total_time_ms'],
              row['mean_time_ms'],
              row['max_time_ms']
            ]
          end
        end

        puts table
      rescue ActiveRecord::StatementInvalid => e
        puts " pg_stat_statements not available: #{e.message}"
        puts "  Install it with: CREATE EXTENSION pg_stat_statements;"
      end
    end

    desc 'Invalidate all performance caches'
    task invalidate_caches: :environment do
      puts 'Invalidating all performance caches...'

      # Database metadata cache
      DatabaseMetadataCacheService.invalidate_all! if defined?(DatabaseMetadataCacheService)
      puts '   Database metadata cache cleared'

      # PgType cache
      PgTypeCache.invalidate_all! if defined?(PgTypeCache)
      puts '   PgType cache cleared'

      # Refresh materialized views
      ActiveRecord::Base.connection.execute('SELECT refresh_database_metadata_views();')
      puts '   Materialized views refreshed'

      puts "\n All caches invalidated and refreshed"
    end

    desc 'Run after migrations to update performance infrastructure'
    task post_migrate: :environment do
      puts 'Running post-migration performance tasks...'

      # Refresh materialized views
      Rake::Task['db:performance:refresh_metadata'].invoke

      # Invalidate caches
      Rake::Task['db:performance:invalidate_caches'].invoke

      puts "\n Post-migration tasks completed"
    end
  end
end
