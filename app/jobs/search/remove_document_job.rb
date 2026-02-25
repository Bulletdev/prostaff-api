# frozen_string_literal: true

module Search
  # Removes a document from Meilisearch.
  # Enqueued by the Searchable concern after_commit on destroy.
  class RemoveDocumentJob < ApplicationJob
    queue_as :search

    # @param model_class_name [String] e.g. "Player"
    # @param record_id        [String] UUID of the document to remove
    def perform(model_class_name, record_id)
      return unless MEILISEARCH_CLIENT

      model_class = model_class_name.constantize
      index       = MEILISEARCH_CLIENT.index(model_class.meili_index_name)
      index.delete_document(record_id)
    rescue StandardError => e
      Rails.logger.error "[Search::RemoveDocumentJob] #{model_class_name}##{record_id}: #{e.message}"
      raise
    end
  end
end
