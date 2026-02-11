# frozen_string_literal: true

namespace :db do
  desc 'Test database connection and RLS status'
  task test_connection: :environment do
    puts '=' * 80
    puts 'DATABASE CONNECTION TEST'
    puts '=' * 80
    puts ''

    # Test basic connection
    puts '1. Testing database connection...'
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      puts '    Connection OK'
    rescue StandardError => e
      puts "    Connection FAILED: #{e.message}"
      exit 1
    end

    # Get database info
    puts ''
    puts '2. Database info:'
    result = ActiveRecord::Base.connection.execute(
      "SELECT current_database(), current_user, version()"
    ).first
    puts "   Database: #{result['current_database']}"
    puts "   User: #{result['current_user']}"
    puts "   Version: #{result['version']}"

    # Check RLS status
    puts ''
    puts '3. Checking RLS status on tables:'
    tables = %w[users organizations players matches]
    tables.each do |table|
      result = ActiveRecord::Base.connection.execute(
        "SELECT rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename = '#{table}'"
      ).first

      if result
        status = result['rowsecurity'] ? ' ENABLED' : ' DISABLED'
        puts "   #{table}: #{status}"
      else
        puts "   #{table}:   TABLE NOT FOUND"
      end
    end

    # Test user query
    puts ''
    puts '4. Testing User.count (should work with RLS disabled):'
    begin
      count = User.count
      puts "    Success! Found #{count} users"
    rescue StandardError => e
      puts "    FAILED: #{e.message}"
      puts "   This usually means RLS is blocking the query"
    end

    # Test User.unscoped
    puts ''
    puts '5. Testing User.unscoped.count (bypasses RLS):'
    begin
      count = User.unscoped.count
      puts "    Success! Found #{count} users"
    rescue StandardError => e
      puts "    FAILED: #{e.message}"
    end

    # Test finding specific user
    puts ''
    puts '6. Testing User.find_by(email: "coach@pain.gg"):'
    begin
      user = User.unscoped.find_by(email: 'coach@pain.gg')
      if user
        puts "    Found user: #{user.email} (#{user.organization.name})"
      else
        puts '     User not found in database'
      end
    rescue StandardError => e
      puts "    FAILED: #{e.message}"
    end

    puts ''
    puts '=' * 80
    puts 'TEST COMPLETE'
    puts '=' * 80
  end
end
