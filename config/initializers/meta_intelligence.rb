# frozen_string_literal: true

# Meta Intelligence Module — Meilisearch Index Setup
#
# Configures searchable/filterable attributes for 'saved_builds' and 'lol_items'
# indexes on every Rails boot. The call is idempotent and silently skipped when
# MEILISEARCH_URL is not set (development without Meilisearch, CI, etc.).
#
# Index schema changes take effect immediately via Meilisearch's async task queue.
# Failures are logged as warnings and never raise — Meilisearch is non-critical.

Rails.application.config.after_initialize do
  next unless ENV['MEILISEARCH_URL'].present?

  # Defer to a thread so it does not block Puma/Unicorn boot.
  Thread.new do
    sleep 2 # small delay to let the process finish booting cleanly

    MetaIntelligence::Services::MetaIndexerService.setup_indexes
    Rails.logger.info '[MetaIntelligence] Meilisearch indexes configured'
  rescue StandardError => e
    Rails.logger.warn "[MetaIntelligence] Index setup skipped: #{e.message}"
  end
end
