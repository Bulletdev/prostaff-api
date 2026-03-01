# frozen_string_literal: true

if ENV['MEILISEARCH_URL'].present?
  MEILISEARCH_CLIENT = Meilisearch::Client.new(
    ENV['MEILISEARCH_URL'],
    ENV['MEILI_MASTER_KEY']
  )
else
  MEILISEARCH_CLIENT = nil
  Rails.logger.warn '[Meilisearch] MEILISEARCH_URL not set — search indexing disabled'
end
