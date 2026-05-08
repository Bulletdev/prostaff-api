# frozen_string_literal: true

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
    resolved = resolve_embeddings(champions)
    present  = resolved.keys
    return empty_result(present) if present.size < 2

    matrix = build_matrix(present, resolved)
    pairs  = build_sorted_pairs(present, matrix)

    {
      champions: present,
      matrix: matrix.map { |row| row.map { |val| val.round(4) } },
      top_pairs: pairs.first(5),
      weakest_pairs: pairs.last(3)
    }
  end

  # ── private ──────────────────────────────────────────────────────────

  def self.empty_result(present)
    { champions: present, matrix: [], top_pairs: [], weakest_pairs: [] }
  end
  private_class_method :empty_result

  def self.resolve_embeddings(champions)
    embs = embeddings
    champions.filter_map do |champ|
      vec = embs[champ] || embs[champ.downcase]
      [champ, vec] if vec
    end.to_h
  end
  private_class_method :resolve_embeddings

  def self.build_matrix(present, resolved)
    present.map.with_index do |champ_a, idx_a|
      present.map.with_index do |champ_b, idx_b|
        idx_a == idx_b ? 1.0 : cosine_similarity(resolved[champ_a], resolved[champ_b])
      end
    end
  end
  private_class_method :build_matrix

  def self.build_sorted_pairs(present, matrix)
    pairs = present.combination(2).map do |champ_a, champ_b|
      ia = present.index(champ_a)
      ib = present.index(champ_b)
      { pair: [champ_a, champ_b], score: matrix[ia][ib].round(4) }
    end
    pairs.sort_by { |entry| -entry[:score] }
  end
  private_class_method :build_sorted_pairs

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

  def self.cosine_similarity(vec_a, vec_b)
    dot = vec_a.zip(vec_b).sum { |x, y| x * y }
    norm_a = Math.sqrt(vec_a.sum { |x| x**2 })
    norm_b = Math.sqrt(vec_b.sum { |x| x**2 })
    return 0.0 if norm_a < 1e-9 || norm_b < 1e-9

    (dot / (norm_a * norm_b)).clamp(-1.0, 1.0)
  end
  private_class_method :cosine_similarity
end
