# frozen_string_literal: true

# Calculates counter advantage between two champions using historical win-rate data.
class CounterCalculator
  MIN_GAMES = 10

  def self.call(attacker:, defender:)
    matrix = AiChampionMatrix.find_by(
      'lower(champion_a) = ? AND lower(champion_b) = ?',
      attacker.downcase, defender.downcase
    )
    return { score: 0.5, advantage: 0.0, games: 0, confidence: 0.0 } unless matrix

    confidence = [matrix.total_games.to_f / MIN_GAMES, 1.0].min

    {
      score: matrix.win_rate.round(4),
      advantage: (matrix.win_rate - 0.5).round(4),
      games: matrix.total_games,
      confidence: confidence.round(4)
    }
  end
end
