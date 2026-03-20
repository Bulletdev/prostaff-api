# frozen_string_literal: true

# Stores historical win-rate data between pairs of champions.
# Global table (no organization_id, no RLS) — aggregates public competitive tournament data.
class AiChampionMatrix < ApplicationRecord
  validates :champion_a, :champion_b, presence: true
  validates :champion_a, uniqueness: { scope: %i[champion_b patch league] }

  scope :with_sufficient_sample, -> { where('total_games >= ?', 10) }

  def self.upsert_win(winner, loser, patch: nil, league: nil)
    matrix = find_or_initialize_by(champion_a: winner, champion_b: loser, patch: patch, league: league)
    matrix.wins_a      = matrix.wins_a.to_i + 1
    matrix.total_games = matrix.total_games.to_i + 1
    matrix.updated_at  = Time.current
    matrix.save!
  end

  def win_rate
    return 0.5 if total_games.zero?

    wins_a.to_f / total_games
  end
end
