# frozen_string_literal: true

# Suggests top-3 5th pick candidates for team_a given current state of the draft.
# Pool: champions that have appeared in competitive matches (stored in ai_champion_vectors).
# Uses WinProbabilityCalculator with a hypothetical 5th pick to score each candidate.
#
# Performance note (A-04): iterates over all champions in the vector table.
# Acceptable for MVP given typical pool size (~80-150 champions). Monitor latency in prod.
class DraftSuggester
  def self.call(team_a:, team_b:)
    new(team_a:, team_b:).suggest
  end

  def suggest
    taken = (@team_a + @team_b).to_set { |c| c.downcase }

    available_champions
      .reject { |champ| taken.include?(champ.downcase) }
      .map    { |champ| { champion: champ, score: score_with(champ) } }
      .sort_by { |r| -r[:score] }
      .first(3)
      .map { |r| r[:champion] }
  end

  private

  def initialize(team_a:, team_b:)
    @team_a = team_a
    @team_b = team_b
  end

  def available_champions
    @available_champions ||= AiChampionVector.pluck(:champion_name)
  end

  def score_with(candidate)
    hypothetical_team = @team_a + [candidate]
    WinProbabilityCalculator.call(
      team_a: hypothetical_team,
      team_b: @team_b,
      synergies: {},
      counters: {}
    )[:score]
  end
end
