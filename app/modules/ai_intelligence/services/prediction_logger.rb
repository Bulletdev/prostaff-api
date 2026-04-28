# frozen_string_literal: true

# Persists ml_v2 draft predictions to the database and to a Redis list for
# the real-time admin dashboard.
#
# Both operations are fire-and-forget: failures are warned and swallowed so
# the logger never blocks or raises in the request cycle.
#
# Redis layout:
#   ml:predictions  — LPUSH/LTRIM list of the last 1 000 prediction summaries (JSON).
#                     Used by the admin widget for quick in-memory queries.
#
# @example Logging a prediction
#   PredictionLogger.log(
#     blue_picks:         %w[Jinx Thresh Azir Gnar Renekton],
#     red_picks:          %w[Caitlyn Nautilus Syndra Graves Camille],
#     predicted_win_prob: 0.6134,
#     source:             'ml_v2',
#     patch:              '16.08',
#     league:             'LCK',
#     model_version:      'champion2vec-v2',
#     match_id:           'match-uuid'
#   )
#
# @example Recording a match outcome
#   PredictionLogger.record_outcome(match_id: 'match-uuid', blue_won: true)
module PredictionLogger
  # Logs a single prediction. Only persists when source == 'ml_v2'.
  #
  # @param blue_picks         [Array<String>]
  # @param red_picks          [Array<String>]
  # @param predicted_win_prob [Float]  win probability for the blue side
  # @param patch              [String, nil]
  # @param league             [String, nil]
  # @param model_version      [String, nil]
  # @param source             [String, nil]  must be 'ml_v2' to persist
  # @param match_id           [String, nil]  optional correlation key
  def self.log(blue_picks:, red_picks:, predicted_win_prob:,
               patch: nil, league: nil, model_version: nil, source: nil, match_id: nil)
    return unless source == 'ml_v2'

    prob = predicted_win_prob.to_f.round(4)

    MlPredictionLog.create!(
      blue_picks:         blue_picks,
      red_picks:          red_picks,
      predicted_win_prob: prob,
      patch:              patch,
      league:             league,
      model_version:      model_version,
      source:             source,
      match_id:           match_id,
      predicted_at:       Time.current
    )

    push_to_redis(prob: prob, source: source)
  rescue StandardError => e
    Rails.logger.warn("[PredictionLogger] log failed: #{e.message}")
  end

  # Back-fills the outcome for all pending predictions tied to a match.
  # Idempotent — only updates rows where blue_won is still NULL.
  #
  # @param match_id [String]
  # @param blue_won [Boolean]
  def self.record_outcome(match_id:, blue_won:)
    MlPredictionLog.where(match_id: match_id, blue_won: nil)
                   .update_all(blue_won: blue_won, outcome_at: Time.current)
  rescue StandardError => e
    Rails.logger.warn("[PredictionLogger] record_outcome failed: #{e.message}")
  end

  # ---------------------------------------------------------------------------
  private_class_method def self.push_to_redis(prob:, source:)
    payload = { prob: prob, at: Time.current.iso8601, source: source }.to_json

    Sidekiq.redis do |r|
      r.call('LPUSH', 'ml:predictions', payload)
      r.call('LTRIM', 'ml:predictions', 0, 999)
    end
  rescue StandardError => e
    Rails.logger.warn("[PredictionLogger] Redis push failed: #{e.message}")
  end
end
