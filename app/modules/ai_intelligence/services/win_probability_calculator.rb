# frozen_string_literal: true

# Calculates win probability for team_a vs team_b given synergy and counter scores.
#
# Algorithm:
# 1. Counter score per matchup (champion A vs champion B): weight 60%
# 2. Synergy score per intra-team pair: weight 40%
# 3. Raw score = weighted average (counter deviation from 0.5, synergy deviation from 0.5)
# 4. Win probability = sigmoid(raw_score * 5) to stretch signal to [0, 1]
# 5. Confidence = average matchup confidence (based on total_games vs MIN_GAMES=10)
class WinProbabilityCalculator
  def self.call(team_a:, team_b:, synergies: {}, counters: {})
    new(team_a:, team_b:, synergies:, counters:).calculate
  end

  def initialize(team_a:, team_b:, synergies:, counters:)
    @team_a    = team_a
    @team_b    = team_b
    @synergies = synergies
    @counters  = counters
  end

  def calculate
    counter_data = collect_counter_data
    synergy_data = collect_synergy_data

    counter_score = average_counter_score(counter_data)
    synergy_score = average_synergy_score(synergy_data)
    confidence    = average_confidence(counter_data)

    raw = (counter_score * 0.6) + (synergy_score * 0.4)

    {
      score: sigmoid(raw).round(4),
      confidence: confidence.round(4)
    }
  end

  private

  def collect_counter_data
    return @counters unless @counters.empty?

    @team_a.product(@team_b).each_with_object({}) do |(a, b), h|
      h[[a, b]] = CounterCalculator.call(attacker: a, defender: b)
    end
  end

  def collect_synergy_data
    return @synergies unless @synergies.empty?

    pairs = @team_a.combination(2).to_a + @team_b.combination(2).to_a
    pairs.each_with_object({}) do |(a, b), h|
      h[[a, b]] = SynergyCalculator.call(champion_a: a, champion_b: b)
    end
  end

  def average_counter_score(counter_data)
    return 0.0 if counter_data.empty?

    scores = counter_data.values.map { |c| c[:score].to_f - 0.5 }
    scores.sum / scores.size.to_f
  end

  def average_synergy_score(synergy_data)
    return 0.0 if synergy_data.empty?

    team_a_pairs = @team_a.combination(2).to_a

    scores = synergy_data.map do |(a, b), v|
      pair_score = v[:score].to_f - 0.5
      team_a_pairs.include?([a, b]) ? pair_score : -pair_score
    end

    scores.sum / scores.size.to_f
  end

  def average_confidence(counter_data)
    return 0.0 if counter_data.empty?

    confidences = counter_data.values.map { |c| c[:confidence].to_f }
    confidences.sum / confidences.size.to_f
  end

  def sigmoid(raw)
    1.0 / (1.0 + Math.exp(-raw * 5))
  end
end
