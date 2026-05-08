# frozen_string_literal: true

# Stores historical win-rate data between pairs of champions.
# Global table (no organization_id, no RLS) — aggregates public competitive tournament data.
class AiChampionMatrix < ApplicationRecord
  validates :champion_a, :champion_b, presence: true
  validates :champion_a, uniqueness: { scope: %i[champion_b patch league] }

  scope :with_sufficient_sample, -> { where('total_games >= ?', 10) }

  UPSERT_WIN_SQL = <<~SQL.squish.freeze
    INSERT INTO ai_champion_matrices
      (champion_a, champion_b, patch, league, wins_a, total_games, updated_at, created_at)
    VALUES (?, ?, ?, ?, 1, 1, NOW(), NOW())
    ON CONFLICT (champion_a, champion_b) WHERE patch IS NULL AND league IS NULL
    DO UPDATE SET wins_a      = ai_champion_matrices.wins_a + 1,
                  total_games = ai_champion_matrices.total_games + 1,
                  updated_at  = NOW()
  SQL

  def self.upsert_win(winner, loser, patch: nil, league: nil)
    connection.execute(sanitize_sql_array([UPSERT_WIN_SQL, winner, loser, patch, league]))
  end

  def win_rate
    return 0.5 if total_games.zero?

    wins_a.to_f / total_games
  end
end
