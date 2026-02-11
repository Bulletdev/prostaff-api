# Prevent Rails from auto-parsing DATABASE_URL when it contains special characters
# This initializer runs BEFORE database configuration is loaded
#
# We use SUPABASE_DB_URL instead and parse it manually in database.yml
# to handle passwords with special characters like @ symbols

if ENV['DATABASE_URL'].present? && ENV['DATABASE_URL'].include?('@@')
  Rails.logger.info "DATABASE_URL contains special characters - will be ignored in favor of manual parsing"

  # Store the original and clear it so Rails doesn't try to parse it
  ENV['_ORIGINAL_DATABASE_URL'] = ENV['DATABASE_URL']
  ENV.delete('DATABASE_URL')
end
