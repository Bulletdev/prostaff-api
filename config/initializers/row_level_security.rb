# frozen_string_literal: true

# Thread-safe and multi-process safe auth schema initialization
module AuthSchemaInitializer
  class << self
    attr_accessor :mutex, :created

    def initialize!
      @mutex = Mutex.new
      @created = false
    end

    def ensure_schema!
      return if @created

      @mutex.synchronize do
        return if @created

        ActiveRecord::Base.connection_pool.with_connection do |conn|
          begin
            # Use CREATE SCHEMA IF NOT EXISTS with exception handling
            # PostgreSQL will handle race conditions internally
            conn.execute('CREATE SCHEMA IF NOT EXISTS auth;')
            Rails.logger.info "✓ Auth schema ensured"
            @created = true
          rescue ActiveRecord::StatementInvalid => e
            # Check if error is "schema already exists" (PostgreSQL error 42P06)
            if e.message.include?('already exists') || e.message.include?('42P06')
              Rails.logger.debug "Auth schema already exists"
              @created = true
            else
              # Re-raise if it's a different error (permissions, etc)
              Rails.logger.error "Failed to create auth schema: #{e.message}"
              raise
            end
          end
        end
      end
    end
  end
end

# Initialize on boot
Rails.application.config.after_initialize do
  AuthSchemaInitializer.initialize!

  # Run in thread to not block boot, but with retry logic
  Thread.new do
    retries = 0
    max_retries = 3

    begin
      sleep 0.5 # Small delay to let other processes/threads start
      AuthSchemaInitializer.ensure_schema!
    rescue => e
      retries += 1
      if retries < max_retries
        sleep 1 * retries # Exponential backoff
        retry
      else
        Rails.logger.error "Failed to ensure auth schema after #{max_retries} attempts: #{e.message}"
      end
    end
  end.tap { |t| t.abort_on_exception = false }
end
