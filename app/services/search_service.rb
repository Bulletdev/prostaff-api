# frozen_string_literal: true

# SearchService — centralizes all Meilisearch queries.

class SearchService
  # Models exposed to global search, keyed by the string callers pass in `types`
  INDEXES = {
    'players' => Player,
    'organizations' => Organization,
    'scouting_targets' => ScoutingTarget,
    'opponent_teams' => OpponentTeam,
    'support_faqs' => SupportFaq
  }.freeze

  # ── Global multi-index search ─────────────────────────────────────
  #
  # @param query    [String]        search term
  # @param types    [Array<String>] limit to these indexes (nil = all)
  # @param per_page [Integer]       hits per index (default 20)
  # @return [Hash] { "players" => [...hits...], "organizations" => [...], ... }
  def self.global(query:, types: nil, per_page: 20)
    return {} if query.blank? || !meilisearch_available?

    target = types.present? ? INDEXES.slice(*Array(types)) : INDEXES
    target.transform_values { |model| search_hits(model, query, per_page) }
  end

  # ── Single-model scope search ─────────────────────────────────────
  #
  # Returns an AR scope preserving Meilisearch relevance order.
  # Returns nil when Meilisearch is unavailable (caller should fallback to SQL).
  #
  # @param model_class [Class]           ActiveRecord model that includes Searchable
  # @param query       [String]          search term
  # @param filters     [Hash]            e.g. { role: "mid", status: "active" }
  # @param limit       [Integer]         max documents from Meilisearch (default 200)
  # @return [ActiveRecord::Relation, nil]
  def self.scope(model_class, query:, filters: {}, limit: 200)
    return nil if query.blank? || !meilisearch_available?

    index  = MEILISEARCH_CLIENT.index(model_class.meili_index_name)
    params = { limit: limit }
    params[:filter] = build_filter(filters) if filters.any?

    result = index.search(query, params)
    ids    = result['hits'].map { |h| h['id'] }
    return model_class.none if ids.empty?

    # Preserve Meilisearch relevance ordering via PostgreSQL array_position
    safe_ids = ids.map { |id| ActiveRecord::Base.connection.quote(id) }.join(',')
    model_class
      .where(id: ids)
      .order(Arel.sql("array_position(ARRAY[#{safe_ids}]::text[], id::text)"))
  rescue StandardError => e
    Rails.logger.warn "[SearchService] Meilisearch unavailable (#{e.class}): #{e.message}"
    nil
  end

  # ── Private helpers ───────────────────────────────────────────────
  private_class_method def self.meilisearch_available?
    MEILISEARCH_CLIENT.present?
  end

  private_class_method def self.search_hits(model_class, query, limit)
    index = MEILISEARCH_CLIENT.index(model_class.meili_index_name)
    index.search(query, limit: limit)['hits']
  rescue StandardError => e
    Rails.logger.warn "[SearchService] Error searching #{model_class.name}: #{e.message}"
    []
  end

  # Builds a Meilisearch filter string from a hash
  # e.g. { role: "mid", status: "active" } → "role = \"mid\" AND status = \"active\""
  private_class_method def self.build_filter(filters)
    filters.map { |k, v| "#{k} = #{v.to_s.inspect}" }.join(' AND ')
  end
end
