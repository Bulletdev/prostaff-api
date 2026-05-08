# frozen_string_literal: true

# Synchronizes meta intelligence data to Meilisearch for full-text search.
#
# Manages two indexes:
#   - 'saved_builds' — org-scoped builds searchable by champion/title/notes
#   - 'lol_items'    — Data Dragon items enriched with org win rate analytics
#
# Failures are logged as warnings (Meilisearch is non-critical infrastructure).
#
# @example Sync builds and items after aggregation
#   indexer = MetaIntelligence::Services::MetaIndexerService.new(organization: org)
#   indexer.sync_builds
#   indexer.sync_items
#
# @example Configure index settings (run once per deployment)
#   MetaIntelligence::Services::MetaIndexerService.setup_indexes
class MetaIndexerService
  BUILDS_INDEX = 'saved_builds'
  ITEMS_INDEX  = 'lol_items'

  # @param organization [Organization]
  def initialize(organization:)
    @organization = organization
  end

  # Configures Meilisearch index settings for both indexes.
  # Idempotent — safe to call on every deploy.
  # @return [void]
  def self.setup_indexes
    new(organization: nil).send(:configure_indexes)
  rescue StandardError => e
    Rails.logger.warn("[MetaIntelligence] Index setup failed: #{e.message}")
  end

  # Indexes all saved builds for the organization into Meilisearch.
  # @return [void]
  def sync_builds
    builds    = @organization.saved_builds
    documents = builds.map { |build| build_document(build) }
    return if documents.empty?

    meilisearch_client.index(BUILDS_INDEX).add_documents(documents)
  rescue StandardError => e
    Rails.logger.warn("[MetaIntelligence] Builds sync failed: #{e.message}")
  end

  # Indexes lol_items enriched with win rate analytics for the organization.
  # Each item document merges Data Dragon metadata with org-specific performance data.
  # @return [void]
  def sync_items
    item_analytics = fetch_item_analytics
    dragon_items   = DataDragonService.new.items
    documents      = build_item_documents(dragon_items, item_analytics)
    return if documents.empty?

    meilisearch_client.index(ITEMS_INDEX).add_documents(documents)
  rescue StandardError => e
    Rails.logger.warn("[MetaIntelligence] Items sync failed: #{e.message}")
  end

  private

  def meilisearch_client
    @meilisearch_client ||= Meilisearch::Client.new(
      ENV.fetch('MEILISEARCH_URL', 'http://localhost:7700'),
      ENV.fetch('MEILI_MASTER_KEY', '')
    )
  end

  # --- Builds ---

  def build_document(build)
    {
      id: build.id,
      champion: build.champion,
      role: build.role,
      title: build.title,
      notes: build.notes,
      organization_id: build.organization_id,
      patch_version: build.patch_version,
      is_public: build.is_public,
      win_rate: build.win_rate.to_f,
      games_played: build.games_played,
      data_source: build.data_source
    }
  end

  # --- Items ---

  def fetch_item_analytics
    ItemAnalyticsService.new(organization: @organization).call
  end

  def build_item_documents(dragon_items, item_analytics)
    dragon_items.filter_map do |item_key, item_data|
      item_id = item_key.to_i
      next if item_id.zero?

      analytics = item_analytics[item_id]
      build_item_document(item_id, item_data, analytics)
    end
  end

  def build_item_document(item_id, item_data, analytics)
    even_stats = analytics&.dig(:even) || { win_rate: 0.0, games: 0 }

    {
      id: item_id,
      name: item_data['name'],
      description: item_data['description'],
      tags: item_data['tags'] || [],
      gold_total: item_data.dig('gold', 'total').to_i,
      organization_id: @organization.id,
      win_rate: even_stats[:win_rate],
      games: analytics ? analytics.values.sum { |s| s[:games] } : 0,
      by_game_state: analytics || {}
    }
  end

  # --- Index configuration ---

  def configure_indexes
    configure_builds_index
    configure_items_index
  end

  def configure_builds_index
    index = meilisearch_client.index(BUILDS_INDEX)
    index.update_searchable_attributes(%w[champion title notes])
    index.update_filterable_attributes(%w[role organization_id is_public patch_version data_source])
    index.update_sortable_attributes(%w[win_rate games_played])
  end

  def configure_items_index
    index = meilisearch_client.index(ITEMS_INDEX)
    index.update_searchable_attributes(%w[name description tags])
    index.update_filterable_attributes(%w[tags organization_id gold_total])
    index.update_sortable_attributes(%w[win_rate games])
  end
end
