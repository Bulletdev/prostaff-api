# frozen_string_literal: true

# Stores historical win-rate data between pairs of champions.
# Global table (no organization_id, no RLS) — aggregates public competitive tournament data.
#
# The table is bidirectional by design: for each matchup (A vs B) there are two rows:
#   (A, B): wins_a = A's wins, total_games = games played
#   (B, A): wins_a = B's wins, total_games = games played
# This allows win-rate lookup from either champion's perspective.
class AiChampionMatrix < ApplicationRecord
  validates :champion_a, :champion_b, presence: true
  validates :champion_a, uniqueness: { scope: %i[champion_b patch league] }

  scope :with_sufficient_sample, -> { where('total_games >= ?', 10) }

  # Single-row upsert kept for ad-hoc / test use.
  # Production bulk path uses bulk_upsert_wins + bulk_record_appearances.
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

  # Bulk-insert win records for all (winner, loser) pairs in one SQL statement.
  # Dispatches to the correct ON CONFLICT clause based on whether patch context is present.
  # Champions within a single match are unique per team, so intra-batch dedup is not required.
  #
  # @param pairs  [Array<Array<String>>]  [[winner, loser], ...]
  # @param patch  [String, nil]
  # @param league [String, nil]
  def self.bulk_upsert_wins(pairs, patch: nil, league: nil)
    return if pairs.empty?

    sql, values = patch.nil? ? build_null_win_sql(pairs) : build_context_win_sql(pairs, patch, league)
    connection.execute(sanitize_sql_array([sql, *values]))
  end

  # Bulk-insert appearance records for all (loser, winner) pairs.
  # Increments total_games only (wins_a stays 0 on insert, unchanged on conflict).
  # This is the inverse of bulk_upsert_wins, completing the bidirectional row pair.
  #
  # @param pairs  [Array<Array<String>>]  [[loser, winner], ...] — note reversed order
  # @param patch  [String, nil]
  # @param league [String, nil]
  def self.bulk_record_appearances(pairs, patch: nil, league: nil)
    return if pairs.empty?

    sql, values = build_null_appearance_sql(pairs)
    connection.execute(sanitize_sql_array([sql, *values]))
  end

  def win_rate
    return 0.5 if total_games.zero?

    wins_a.to_f / total_games
  end

  # -- private class methods --------------------------------------------------

  def self.build_null_win_sql(pairs)
    row_ph = Array.new(pairs.size, '(?, ?, NULL, NULL, 1, 1, NOW(), NOW())').join(', ')
    sql = <<~SQL
      INSERT INTO ai_champion_matrices
        (champion_a, champion_b, patch, league, wins_a, total_games, updated_at, created_at)
      VALUES #{row_ph}
      ON CONFLICT (champion_a, champion_b) WHERE patch IS NULL AND league IS NULL
      DO UPDATE SET wins_a      = ai_champion_matrices.wins_a + 1,
                    total_games = ai_champion_matrices.total_games + 1,
                    updated_at  = NOW()
    SQL
    [sql, pairs.flat_map { |p| [p.first, p.last] }]
  end
  private_class_method :build_null_win_sql

  def self.build_context_win_sql(pairs, patch, league)
    row_ph = Array.new(pairs.size, '(?, ?, ?, ?, 1, 1, NOW(), NOW())').join(', ')
    sql = <<~SQL
      INSERT INTO ai_champion_matrices
        (champion_a, champion_b, patch, league, wins_a, total_games, updated_at, created_at)
      VALUES #{row_ph}
      ON CONFLICT (champion_a, champion_b, patch, league)
        WHERE patch IS NOT NULL AND league IS NOT NULL
      DO UPDATE SET wins_a      = ai_champion_matrices.wins_a + 1,
                    total_games = ai_champion_matrices.total_games + 1,
                    updated_at  = NOW()
    SQL
    [sql, pairs.flat_map { |p| [p.first, p.last, patch, league] }]
  end
  private_class_method :build_context_win_sql

  def self.build_null_appearance_sql(pairs)
    row_ph = Array.new(pairs.size, '(?, ?, NULL, NULL, 0, 1, NOW(), NOW())').join(', ')
    sql = <<~SQL
      INSERT INTO ai_champion_matrices
        (champion_a, champion_b, patch, league, wins_a, total_games, updated_at, created_at)
      VALUES #{row_ph}
      ON CONFLICT (champion_a, champion_b) WHERE patch IS NULL AND league IS NULL
      DO UPDATE SET total_games = ai_champion_matrices.total_games + 1,
                    updated_at  = NOW()
    SQL
    [sql, pairs.flat_map { |p| [p.first, p.last] }]
  end
  private_class_method :build_null_appearance_sql
end
