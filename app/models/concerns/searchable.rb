# frozen_string_literal: true

# Searchable — ActiveRecord concern for Meilisearch indexing
#
# Including models must implement:
#   - self.meili_searchable_attributes → Array<String>  (fields Meilisearch indexes for full-text)
#   - self.meili_filterable_attributes → Array<String>  (fields usable as filters/facets)
#   - #to_meili_document               → Hash           (document sent to Meilisearch)
#
# Indexing is async via Sidekiq (Search::IndexDocumentJob / Search::RemoveDocumentJob).
# All operations degrade gracefully when MEILISEARCH_CLIENT is nil.
module Searchable
  extend ActiveSupport::Concern

  included do
    after_commit :enqueue_meili_index,  on: %i[create update]
    after_commit :enqueue_meili_remove, on: :destroy
  end

  class_methods do
    # Meilisearch index name derived from model name (e.g. ScoutingTarget → "scouting_targets")
    def meili_index_name
      name.underscore.pluralize
    end

    # Returns the Meilisearch::Index object for this model
    def meili_index
      MEILISEARCH_CLIENT&.index(meili_index_name)
    end

    # Fields used for full-text search (must be overridden)
    def meili_searchable_attributes
      raise NotImplementedError, "#{self} must define .meili_searchable_attributes"
    end

    # Fields available as filters (optional override)
    def meili_filterable_attributes
      []
    end

    # Configures index settings and bulk-indexes all records.
    # Intended for: rake search:reindex
    def meili_reindex!
      index = meili_index
      return Rails.logger.warn('[Searchable] Skipping reindex — Meilisearch not configured') unless index

      index.update_settings(
        searchable_attributes: meili_searchable_attributes,
        filterable_attributes: meili_filterable_attributes
      )

      docs = find_each(batch_size: 200).map(&:to_meili_document)
      index.add_or_update_documents(docs) if docs.any?

      Rails.logger.info "[Searchable] Reindexed #{docs.size} #{name} documents"
    end
  end

  # Document hash sent to Meilisearch (must be overridden)
  def to_meili_document
    raise NotImplementedError, "#{self.class} must implement #to_meili_document"
  end

  private

  def enqueue_meili_index
    return unless MEILISEARCH_CLIENT

    Search::IndexDocumentJob.perform_later(self.class.name, id.to_s)
  rescue StandardError => e
    Rails.logger.error "[Searchable] Failed to enqueue index for #{self.class}##{id}: #{e.message}"
  end

  def enqueue_meili_remove
    return unless MEILISEARCH_CLIENT

    Search::RemoveDocumentJob.perform_later(self.class.name, id.to_s)
  rescue StandardError => e
    Rails.logger.error "[Searchable] Failed to enqueue removal for #{self.class}##{id}: #{e.message}"
  end
end
