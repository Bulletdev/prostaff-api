# frozen_string_literal: true

module Search
  # Indexes (creates or updates) a single document in Meilisearch.
  # Enqueued by the Searchable concern after_commit on create/update.
  class IndexDocumentJob < ApplicationJob
    queue_as :search

    # @param model_class_name [String] e.g. "Player"
    # @param record_id        [String] UUID of the record
    def perform(model_class_name, record_id)
      return unless MEILISEARCH_CLIENT

      model_class = model_class_name.constantize
      record      = model_class.find_by(id: record_id)
      return unless record

      index = MEILISEARCH_CLIENT.index(model_class.meili_index_name)
      index.add_or_update_documents([record.to_meili_document])
    rescue StandardError => e
      Rails.logger.error "[Search::IndexDocumentJob] #{model_class_name}##{record_id}: #{e.message}"
      raise # Re-raise so Sidekiq retries
    end
  end
end
