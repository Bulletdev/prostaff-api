# frozen_string_literal: true

# Calculates synergy between two champions using cosine similarity of their performance vectors.
class SynergyCalculator
  def self.call(champion_a:, champion_b:)
    vec_a = load_vector(champion_a)
    vec_b = load_vector(champion_b)
    return { score: 0.5, confidence: :low, games: 0 } if vec_a.nil? || vec_b.nil?

    score = cosine_similarity(vec_a.vector, vec_b.vector)
    { score: score.round(4), games: [vec_a.games_count, vec_b.games_count].min }
  end

  def self.load_vector(champion_name)
    AiChampionVector.find_by('lower(champion_name) = ?', champion_name.downcase)
  end
  private_class_method :load_vector

  def self.cosine_similarity(vec_a, vec_b)
    dot    = (vec_a * vec_b).sum
    norm_a = Math.sqrt((vec_a**2).sum)
    norm_b = Math.sqrt((vec_b**2).sum)
    return 0.0 if norm_a.zero? || norm_b.zero?

    dot / (norm_a * norm_b)
  end
  private_class_method :cosine_similarity
end
