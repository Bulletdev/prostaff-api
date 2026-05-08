# frozen_string_literal: true

# Centralizes all Meilisearch queries, supporting global multi-index search
# and scoped per-model queries with optional organization filtering.
#
# When Meilisearch is unavailable the global search degrades gracefully by
# falling back to a PostgreSQL ILIKE query on models that support it.
class SearchService
  # Models exposed to global search, keyed by the string callers pass in `types`
  INDEXES = {
    'players' => Player,
    'organizations' => Organization,
    'scouting_targets' => ScoutingTarget,
    'opponent_teams' => OpponentTeam,
    'support_faqs' => SupportFaq
  }.freeze

  # Models that have both an `organization_id` column and a `name`-like column
  # suitable for the postgres_fallback query.  Only Player has both.
  # ScoutingTarget lacks organization_id; Organization/SupportFaq lack the
  # scoping we need for multi-tenant safety.
  POSTGRES_FALLBACK_MODELS = {
    'players' => Player
  }.freeze

  # ── Global multi-index search ─────────────────────────────────────
  #
  # @param query          [String]        search term
  # @param types          [Array<String>] limit to these indexes (nil = all)
  # @param per_page       [Integer]       hits per index (default 20)
  # @param organization_id [String, nil]  UUID used by the postgres fallback
  # @return [Hash] { "players" => [...hits...], "organizations" => [...], ... }
  def self.global(query:, types: nil, per_page: 20, organization_id: nil)
    return {} if query.blank?

    if meilisearch_available?
      target = types.present? ? INDEXES.slice(*Array(types)) : INDEXES
      return target.transform_values { |model| search_hits(model, query, per_page) }
    end

    return {} if organization_id.blank?

    fallback_global(query: query, types: types, organization_id: organization_id)
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

  # ── PostgreSQL fallback ───────────────────────────────────────────
  #
  # Used when Meilisearch is unavailable.  Only works for models that have
  # both `organization_id` and a `summoner_name`/`name` column.
  #
  # @param model_class    [Class]  ActiveRecord model
  # @param query          [String] search term (will be SQL-escaped)
  # @param organization_id [String] UUID to scope the query
  # @return [ActiveRecord::Relation]
  def self.postgres_fallback(model_class, query:, organization_id:)
    sanitized = ActiveRecord::Base.sanitize_sql_like(query)
    model_class
      .where(organization_id: organization_id)
      .where('name ILIKE ?', "%#{sanitized}%")
      .limit(20)
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

  # Executes PostgreSQL ILIKE fallback for models in POSTGRES_FALLBACK_MODELS.
  # Returns a hash of arrays compatible with the normal global response shape.
  #
  # @param query          [String]
  # @param types          [Array<String>, nil]
  # @param organization_id [String]
  # @return [Hash]
  private_class_method def self.fallback_global(query:, types:, organization_id:)
    target = types.present? ? POSTGRES_FALLBACK_MODELS.slice(*Array(types)) : POSTGRES_FALLBACK_MODELS
    target.transform_values do |model|
      sanitized = ActiveRecord::Base.sanitize_sql_like(query)
      model
        .where(organization_id: organization_id)
        .where('summoner_name ILIKE ?', "%#{sanitized}%")
        .limit(20)
    end
  rescue StandardError => e
    Rails.logger.warn "[SearchService] PostgreSQL fallback failed: #{e.message}"
    {}
  end
end
