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

# Database safety protection module
module DatabaseSafetyProtection
  REMOTE_INDICATORS = %w[supabase aws rds heroku render railway].freeze

  DANGEROUS_TASKS = %w[
    db:drop
    db:drop:_unsafe
    db:reset
    db:schema:load
    db:structure:load
    db:purge
    db:test:purge
    db:migrate:reset
  ].freeze

  module_function

  def remote_database?
    return false unless defined?(ActiveRecord::Base)

    host = database_host
    REMOTE_INDICATORS.any? { |indicator| host.include?(indicator) }
  rescue StandardError
    false
  end

  def database_host
    ActiveRecord::Base.connection_db_config.configuration_hash[:host].to_s
  end

  def database_config
    ActiveRecord::Base.connection_db_config.configuration_hash
  end

  def block_dangerous_tasks!
    DANGEROUS_TASKS.each do |task_name|
      block_task(task_name) if task_defined?(task_name)
    end
  end

  def task_defined?(task_name)
    Rake::Task.task_defined?(task_name)
  end

  def block_task(task_name)
    task = Rake::Task[task_name]
    task.clear_actions
    task.actions << create_blocking_action(task_name)
  end

  def create_blocking_action(task_name)
    proc do
      display_blocking_message(task_name)
      abort '❌ Operation aborted to protect your data!'
    end
  end

  def display_blocking_message(task_name)
    print_blocking_header(task_name)
    print_connection_info
    print_fix_instructions
  end

  def print_blocking_header(task_name)
    puts "\n#{'=' * 70}"
    puts '🚨 CRITICAL: DESTRUCTIVE DATABASE OPERATION BLOCKED!'
    puts('=' * 70)
    puts "\n❌ Task '#{task_name}' blocked on REMOTE DATABASE!"
  end

  def print_connection_info
    config = database_config
    puts "\n📍 Current Connection:"
    puts "   Host:     #{config[:host]}"
    puts "   Database: #{config[:database]}"
    puts "   User:     #{config[:username]}"
    puts "\n🛡️  This operation has been BLOCKED to prevent data loss."
  end

  def print_fix_instructions
    puts "\n💡 To fix this:"
    puts '   1. Verify your .env file is NOT pointing to production'
    puts '   2. Use local database for development/testing'
    puts '   3. Check config/database.yml configuration'
    puts "\n   Run: ./bin/check_db_connection"
    puts "\n#{'=' * 70}\n"
  end

  def log_remote_connection_warning
    config = database_config
    Rails.logger.warn "\n#{'!' * 70}"
    Rails.logger.warn '⚠️  WARNING: Connected to REMOTE database!'
    Rails.logger.warn "   Host: #{config[:host]}"
    Rails.logger.warn '   Destructive operations are BLOCKED'
    Rails.logger.warn "#{'!' * 70}\n"
  end
end

# Only run this protection in non-production environments
unless Rails.env.production?
  Rails.application.config.after_initialize do
    next unless defined?(Rake::Task) && DatabaseSafetyProtection.remote_database?

    DatabaseSafetyProtection.block_dangerous_tasks!
    DatabaseSafetyProtection.log_remote_connection_warning
  end
end

# Additional safety: Prevent schema loading in console if remote
if defined?(Rails::Console) && !Rails.env.production?
  Rails.application.config.after_initialize do
    next unless defined?(ActiveRecord::Base)
    next unless DatabaseSafetyProtection.remote_database?

    host = DatabaseSafetyProtection.database_host
    puts "\n#{'⚠️ ' * 35}"
    puts '⚠️  CAUTION: Rails console connected to REMOTE database!'
    puts "⚠️  Host: #{host}"
    puts '⚠️  Be VERY careful with destructive operations!'
    puts "#{'⚠️ ' * 35}\n"
  end
end
