# frozen_string_literal: true

# Main entry point for AI draft analysis.
# Orchestrates synergy, counter, and win probability calculations.
class DraftAnalyzer
  Result = Struct.new(:win_probability, :confidence, :synergy_scores,
                      :counter_scores, :suggested_picks, :low_sample, :source, keyword_init: true)

  def self.call(team_a:, team_b:, patch: nil)
    new(team_a:, team_b:, patch:).analyze
  end

  def analyze
    synergies   = calculate_synergies
    counters    = calculate_counters
    suggestions = DraftSuggester.call(team_a: @team_a, team_b: @team_b) if @team_a.size == 4

    ml_result = MlDraftService.call(team_a: @team_a, team_b: @team_b, patch: @patch, league: nil)

    if ml_result
      Result.new(
        win_probability: ml_result[:win_probability].round(4),
        confidence:      ml_result[:confidence].round(4),
        synergy_scores:  synergies,
        counter_scores:  counters,
        suggested_picks: suggestions,
        low_sample:      ml_result[:confidence] < 0.5,
        source:          'ml_v2'
      )
    else
      win_prob = WinProbabilityCalculator.call(
        team_a: @team_a, team_b: @team_b,
        synergies:, counters:
      )
      Result.new(
        win_probability: win_prob[:score].round(4),
        confidence:      win_prob[:confidence].round(4),
        synergy_scores:  synergies,
        counter_scores:  counters,
        suggested_picks: suggestions,
        low_sample:      win_prob[:confidence] < 0.5,
        source:          'legacy_ruby'
      )
    end
  end

  private

  def initialize(team_a:, team_b:, patch:)
    @team_a = team_a
    @team_b = team_b
    @patch  = patch # accepted but unused in MVP; v2 will use for patch filtering
  end

  def calculate_synergies
    pairs = @team_a.combination(2).to_a + @team_b.combination(2).to_a
    pairs.each_with_object({}) do |(a, b), h|
      h[[a, b]] = SynergyCalculator.call(champion_a: a, champion_b: b)
    end
  end

  def calculate_counters
    @team_a.product(@team_b).each_with_object({}) do |(a, b), h|
      h[[a, b]] = CounterCalculator.call(attacker: a, defender: b)
    end
  end
end
