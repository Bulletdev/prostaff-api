# frozen_string_literal: true

# Reads CompetitiveMatch records (via unscoped) and builds the ai_champion_matrices table.
# victory=true means our_picks won; victory=false means opponent_picks won.
class ChampionMatrixBuilder
  def initialize(scope: :all, league: nil)
    @scope  = scope
    @league = league
  end

  def self.call(scope: :all, league: nil)
    new(scope:, league:).build
  end

  def build
    AiChampionMatrix.delete_all if @scope == :all

    query = CompetitiveMatch.unscoped
    query = query.where(tournament_name: @league) if @league

    query.find_each do |match|
      winner_picks = match.victory ? match.our_picks : match.opponent_picks
      loser_picks  = match.victory ? match.opponent_picks : match.our_picks

      next if winner_picks.blank? || loser_picks.blank?

      register_matchups(winner_picks, loser_picks)
    end
  end

  RECORD_APPEARANCE_SQL = <<~SQL.squish.freeze
    INSERT INTO ai_champion_matrices
      (champion_a, champion_b, patch, league, wins_a, total_games, updated_at, created_at)
    VALUES (?, ?, NULL, NULL, 0, 1, NOW(), NOW())
    ON CONFLICT (champion_a, champion_b) WHERE patch IS NULL AND league IS NULL
    DO UPDATE SET total_games = ai_champion_matrices.total_games + 1,
                  updated_at  = NOW()
  SQL

  private

  def register_matchups(winner_picks, loser_picks)
    winner_champions = winner_picks.map { |p| p['champion'] }.compact
    loser_champions  = loser_picks.map  { |p| p['champion'] }.compact

    winner_champions.each do |winner|
      loser_champions.each do |loser|
        AiChampionMatrix.upsert_win(winner, loser)
        record_appearance(loser, winner)
      end
    end
  end

  def record_appearance(champion_a, champion_b)
    sql = AiChampionMatrix.sanitize_sql_array([RECORD_APPEARANCE_SQL, champion_a, champion_b])
    AiChampionMatrix.connection.execute(sql)
  end
end
