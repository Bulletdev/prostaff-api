# frozen_string_literal: true

# Serializes DraftAnalyzer::Result for the POST /api/v1/ai/draft/analyze response.
class DraftAnalysisBlueprint < Blueprinter::Base
  field :win_probability
  field :confidence
  field :low_sample

  field :top_synergies do |result|
    result.synergy_scores
          .sort_by { |_, v| -v[:score].to_f }
          .first(5)
          .map { |(a, b), v| { pair: [a, b], score: v[:score], games: v[:games] } }
  end

  field :top_counters do |result|
    result.counter_scores
          .sort_by { |_, v| -v[:advantage].to_f.abs }
          .first(5)
          .map do |(a, b), v|
      { matchup: [a, b], advantage: v[:advantage], games: v[:games],
        confidence: v[:confidence] }
    end
  end

  field :suggested_picks do |result|
    result.suggested_picks || []
  end
end
