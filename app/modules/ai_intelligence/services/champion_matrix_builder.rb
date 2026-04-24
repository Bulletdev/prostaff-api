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
    AiChampionMatrix.upsert(
      { champion_a: champion_a, champion_b: champion_b, patch: nil, league: nil,
        wins_a: 0, total_games: 1, updated_at: Time.current },
      unique_by: :index_ai_champion_matrices_null_pair,
      on_duplicate: Arel.sql(
        'total_games = ai_champion_matrices.total_games + 1, ' \
        'updated_at = excluded.updated_at'
      )
    )
  end
end
