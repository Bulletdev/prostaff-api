source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.5"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.0"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 6.0"

# Security: Force Rack to safe version to fix CVE-2025-61780 and CVE-2025-61919
gem "rack", "~> 3.1.18"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 5.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem "rack-cors"

# JWT for authentication
gem "jwt"

# Serializers for API responses
gem "blueprinter"

# Background jobs
gem "sidekiq", "~> 7.0"
gem "sidekiq-scheduler"

# Environment variables
gem "dotenv-rails"

# HTTP client for Riot API
gem "faraday"
gem "faraday-retry"

# Authorization
gem "pundit"

# Rate limiting
gem "rack-attack"

# UUID generation
gem "securerandom"

# Pagination
gem "kaminari"

# API documentation
gem "rswag"
gem "rswag-api"
gem "rswag-ui"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "rswag-specs"
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
  gem "annotate"
  gem "rubocop"
  gem "rubocop-rails"
  gem "rubocop-rspec"
end

group :test do
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
  gem "webmock"
  gem "vcr"
  gem "simplecov", require: false
end