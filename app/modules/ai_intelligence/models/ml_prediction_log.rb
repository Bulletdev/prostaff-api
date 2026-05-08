# frozen_string_literal: true

# Stores every ml_v2 draft prediction for offline quality monitoring.
#
# Global table (no organization_id) — captures tournament-level signal across all teams.
# Outcomes are back-filled via PredictionLogger.record_outcome when a match result
# is known (blue_won is NULL until then).
#
# Used by RollingAucJob to calculate a rolling AUC-ROC over the last 200 settled
# predictions and persist it to Redis for the admin dashboard.
class MlPredictionLog < ApplicationRecord
  validates :blue_picks, :red_picks, :predicted_win_prob, presence: true

  # Predictions that already have an outcome — eligible for AUC calculation.
  scope :with_outcome, -> { where.not(blue_won: nil) }

  # Most recent N predictions, regardless of outcome.
  scope :recent, ->(n) { order(predicted_at: :desc).limit(n) }
end
