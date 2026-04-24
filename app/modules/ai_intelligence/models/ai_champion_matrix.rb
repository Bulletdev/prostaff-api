# frozen_string_literal: true

# Stores historical win-rate data between pairs of champions.
# Global table (no organization_id, no RLS) — aggregates public competitive tournament data.
class AiChampionMatrix < ApplicationRecord
  validates :champion_a, :champion_b, presence: true
  validates :champion_a, uniqueness: { scope: %i[champion_b patch league] }

  scope :with_sufficient_sample, -> { where('total_games >= ?', 10) }

  def self.upsert_win(winner, loser, patch: nil, league: nil)
    # Two separate partial indexes cover the two cases:
    # - both null  → index_ai_champion_matrices_null_pair
    # - both present → index_ai_champion_matrices_unique
    index = if patch.nil? && league.nil?
              :index_ai_champion_matrices_null_pair
            else
              :index_ai_champion_matrices_unique
            end
    upsert(
      { champion_a: winner, champion_b: loser, patch: patch, league: league,
        wins_a: 1, total_games: 1, updated_at: Time.current },
      unique_by: index,
      on_duplicate: Arel.sql(
        'wins_a = ai_champion_matrices.wins_a + 1, ' \
        'total_games = ai_champion_matrices.total_games + 1, ' \
        'updated_at = excluded.updated_at'
      )
    )
  end

  def win_rate
    return 0.5 if total_games.zero?

    wins_a.to_f / total_games
  end
end
