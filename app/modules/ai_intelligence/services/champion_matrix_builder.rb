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
    AiChampionMatrix
      .find_or_initialize_by(champion_a:, champion_b:)
      .tap do |m|
      m.total_games = m.total_games.to_i + 1
      m.updated_at = Time.current
      m.save!
    end
  end
end
