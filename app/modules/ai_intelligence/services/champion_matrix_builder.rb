# frozen_string_literal: true

# Reads CompetitiveMatch records (via unscoped) and builds the ai_champion_matrices table.
# victory=true means our_picks won; victory=false means opponent_picks won.
#
# Each call to register_matchups issues exactly two SQL statements regardless of
# how many champion pairs are present: one bulk upsert for win records (winner, loser)
# and one bulk insert for appearance records (loser, winner).
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

    win_pairs        = build_pairs(winner_champions, loser_champions)
    appearance_pairs = build_pairs(loser_champions, winner_champions)

    return if win_pairs.empty?

    AiChampionMatrix.bulk_upsert_wins(win_pairs)
    AiChampionMatrix.bulk_record_appearances(appearance_pairs)
  end

  # Returns all ordered pairs (a, b) for every combination of champions_a x champions_b.
  def build_pairs(champions_a, champions_b)
    champions_a.flat_map { |a| champions_b.map { |b| [a, b] } }
  end
end
