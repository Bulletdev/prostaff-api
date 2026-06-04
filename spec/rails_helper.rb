# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
# Force test environment even when the container env has RAILS_ENV=development.
ENV['RAILS_ENV'] = 'test'
require_relative '../config/environment'
require 'webmock/rspec'
WebMock.allow_net_connect!
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
require 'database_cleaner/active_record'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories.
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# When generating Swagger docs (RSWAG_GENERATE=1 + --dry-run), skip all
# database-related checks — no actual queries are executed in dry-run mode.
RSWAG_GENERATE = ENV['RSWAG_GENERATE'] == '1'

# Checks for pending migrations and applies them before tests are run.
unless RSWAG_GENERATE
  begin
    ActiveRecord::Migration.maintain_test_schema!
  rescue ActiveRecord::PendingMigrationError => e
    abort e.to_s.strip
  end
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = !RSWAG_GENERATE

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Include request helpers
  config.include RequestSpecHelper, type: :request

  unless RSWAG_GENERATE
    # Abort if any known production URL is set — catches the most common cases.
    # TEST_DATABASE_URL is what database.yml actually uses in test env;
    # DATABASE_URL is checked as a fallback for misconfigured environments.
    [ENV['TEST_DATABASE_URL'], ENV['DATABASE_URL']].compact.each do |url|
      if url.include?('supabase') || url.include?('prod') || url.include?('pooler')
        abort('CRITICAL: Cannot run tests against production database! Use a local test database.')
      end
    end

    # DatabaseCleaner's built-in remote URL safeguard only recognises
    # localhost/127.0.0.1 as safe. Docker-network hostnames (e.g.
    # docker-postgres-1) are flagged as remote even though they are
    # test-only containers. The guard above is the authoritative protection;
    # allow_remote_database_url avoids the false-positive block.
    DatabaseCleaner.allow_remote_database_url = true

    config.before(:suite) do
      DatabaseCleaner.clean_with(:truncation)
    end

    config.before(:each) do
      DatabaseCleaner.strategy = :transaction
    end

    config.before(:each) do
      DatabaseCleaner.start
    end

    config.after(:each) do
      DatabaseCleaner.clean
    end
  end
end

# Shoulda Matchers configuration
begin
  require 'shoulda/matchers'
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
rescue LoadError
  # Shoulda matchers not available
end
