# frozen_string_literal: true

# Database Safety Initializer
#
# CRITICAL PROTECTION: Prevents accidental data loss by blocking destructive
# database operations when connected to remote/production databases.
#
# This initializer will ABORT any attempt to:
# - Drop databases
# - Reset databases
# - Load schema (which drops all tables)
# - Purge databases
#
# ...if the connection is pointing to a remote database (Supabase, AWS, etc.)

# Only run this protection in non-production environments
unless Rails.env.production?
  Rails.application.config.after_initialize do
    # Check if we're connected to a remote database
    def remote_database?
      return false unless defined?(ActiveRecord::Base)

      begin
        config = ActiveRecord::Base.connection_db_config.configuration_hash
        host = config[:host].to_s

        # Check for remote database indicators
        remote_indicators = [
          'supabase',
          'aws',
          'rds',
          'heroku',
          'render',
          'railway'
        ]

        remote_indicators.any? { |indicator| host.include?(indicator) }
      rescue StandardError
        false
      end
    end

    # Block destructive rake tasks if connected to remote database
    if defined?(Rake::Task) && remote_database?
      # List of dangerous tasks that should never run on remote databases
      dangerous_tasks = [
        'db:drop',
        'db:drop:_unsafe',
        'db:reset',
        'db:schema:load',
        'db:structure:load',
        'db:purge',
        'db:test:purge',
        'db:migrate:reset'
      ]

      dangerous_tasks.each do |task_name|
        next unless Rake::Task.task_defined?(task_name)

        task = Rake::Task[task_name]

        # Clear existing actions
        task.clear_actions

        # Replace with blocking action
        task.actions << proc do
          config = ActiveRecord::Base.connection_db_config.configuration_hash

          puts "\n" + ("=" * 70)
          puts "🚨 CRITICAL: DESTRUCTIVE DATABASE OPERATION BLOCKED!"
          puts ("=" * 70)
          puts "\n❌ Task '#{task_name}' is attempting to run on a REMOTE DATABASE!"
          puts "\n📍 Current Connection:"
          puts "   Host:     #{config[:host]}"
          puts "   Database: #{config[:database]}"
          puts "   User:     #{config[:username]}"
          puts "\n🛡️  This operation has been BLOCKED to prevent data loss."
          puts "\n💡 To fix this:"
          puts "   1. Verify your .env file is NOT pointing to production"
          puts "   2. Use local database for development/testing"
          puts "   3. Check config/database.yml configuration"
          puts "\n   Run: ./bin/check_db_connection"
          puts "\n" + ("=" * 70) + "\n"

          abort "❌ Operation aborted to protect your data!"
        end
      end

      # Log warning at startup
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      Rails.logger.warn "\n" + ("!" * 70)
      Rails.logger.warn "⚠️  WARNING: Connected to REMOTE database!"
      Rails.logger.warn "   Host: #{config[:host]}"
      Rails.logger.warn "   Destructive operations are BLOCKED"
      Rails.logger.warn ("!" * 70) + "\n"
    end
  end
end

# Additional safety: Prevent schema loading in console if remote
if defined?(Rails::Console) && !Rails.env.production?
  Rails.application.config.after_initialize do
    if defined?(ActiveRecord::Base)
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      host = config[:host].to_s

      if host.include?('supabase') || host.include?('aws')
        puts "\n" + ("⚠️ " * 35)
        puts "⚠️  CAUTION: Rails console connected to REMOTE database!"
        puts "⚠️  Host: #{host}"
        puts "⚠️  Be VERY careful with destructive operations!"
        puts ("⚠️ " * 35) + "\n"
      end
    end
  end
end
