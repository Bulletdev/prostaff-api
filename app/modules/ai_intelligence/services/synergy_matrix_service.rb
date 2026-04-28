# frozen_string_literal: true

module AiIntelligence
  # Calculates an N×N cosine-similarity matrix from 64-dimensional champion embeddings.
  #
  # Embeddings are loaded once per 24h from champion_embeddings_64d.json via Rails.cache.
  # Primary path:  ai_service/data/champion_embeddings_64d.json
  # Fallback path: models/champion_embeddings_64d.json  (prostaff-ml artefact)
  class SynergyMatrixService
    EMBEDDINGS_FILE = Rails.root.join('ai_service', 'data', 'champion_embeddings_64d.json').freeze
    FALLBACK_FILE   = Rails.root.join('models', 'champion_embeddings_64d.json').freeze
    CACHE_KEY       = 'ai_intelligence/champion_embeddings_64d'
    CACHE_TTL       = 24.hours

    # @param champions [Array<String>] 2–10 champion names
    # @return [Hash] { champions:, matrix:, top_pairs:, weakest_pairs: }
    def self.call(champions:)
      embs = embeddings
      resolved = champions.filter_map do |c|
        vec = embs[c] || embs[c.downcase]
        [c, vec] if vec
      end.to_h

      present = resolved.keys
      return { champions: present, matrix: [], top_pairs: [], weakest_pairs: [] } if present.size < 2

      matrix = present.map.with_index do |a, i|
        present.map.with_index do |b, j|
          i == j ? 1.0 : cosine_similarity(resolved[a], resolved[b])
        end
      end

      pairs = []
      present.combination(2).each do |a, b|
        ia = present.index(a)
        ib = present.index(b)
        pairs << { pair: [a, b], score: matrix[ia][ib].round(4) }
      end
      pairs.sort_by! { |p| -p[:score] }

      {
        champions:     present,
        matrix:        matrix.map { |row| row.map { |v| v.round(4) } },
        top_pairs:     pairs.first(5),
        weakest_pairs: pairs.last(3)
      }
    end

    # ── private ──────────────────────────────────────────────────────────

    def self.embeddings
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { load_embeddings }
    end
    private_class_method :embeddings

    def self.load_embeddings
      path = EMBEDDINGS_FILE.exist? ? EMBEDDINGS_FILE : FALLBACK_FILE
      raise "Champion embeddings file not found (tried #{EMBEDDINGS_FILE} and #{FALLBACK_FILE})" unless path.exist?

      JSON.parse(File.read(path))
    end
    private_class_method :load_embeddings

    def self.cosine_similarity(a, b)
      dot = a.zip(b).sum { |x, y| x * y }
      na  = Math.sqrt(a.sum { |x| x**2 })
      nb  = Math.sqrt(b.sum { |x| x**2 })
      return 0.0 if na < 1e-9 || nb < 1e-9

      (dot / (na * nb)).clamp(-1.0, 1.0)
    end
    private_class_method :cosine_similarity
  end
end
