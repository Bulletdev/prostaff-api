# frozen_string_literal: true

# Nightly job that computes a rolling AUC-ROC over the last 200 settled ml_v2
# predictions and writes monitoring metrics to Redis for the admin dashboard.
#
# Scheduled at 03:00 UTC via sidekiq-cron (see config/sidekiq.yml or
# config/schedule.yml depending on the project setup). The job is entirely
# silent when fewer than 50 outcomes are available — it simply returns early
# without logging anything at warn/error level.
#
# Redis keys written:
#   ml:metrics:rolling_auc       — AUC-ROC rounded to 4 decimal places (string)
#   ml:metrics:n_predictions     — sample size used (string)
#   ml:metrics:mean_win_prob     — mean predicted probability (string)
#
# Alert thresholds:
#   AUC  < 0.51          → model is no better than random; warn in logs
#   mean < 0.48 or > 0.58 → systematic probability drift; warn in logs
#
# AUC-ROC algorithm: pure Ruby trapezoidal method — no external gems required.
# Sort predictions by descending score, walk the list accumulating true/false
# positives, and sum the trapezoid areas.
class RollingAucJob < ApplicationJob
  queue_as :low_priority
  sidekiq_options retry: 0

  MIN_SAMPLE = 50
  SAMPLE_SIZE = 200

  def perform
    logs = MlPredictionLog.with_outcome.recent(SAMPLE_SIZE).to_a
    return if logs.size < MIN_SAMPLE

    y_true  = logs.map { |l| l.blue_won ? 1 : 0 }
    y_score = logs.map { |l| l.predicted_win_prob.to_f }

    auc       = calculate_auc_roc(y_true, y_score)
    mean_prob = y_score.sum / y_score.size

    persist_metrics(auc: auc.round(4), n: logs.size, mean_prob: mean_prob.round(4))
    emit_alerts(auc: auc, mean_prob: mean_prob, n: logs.size)

    record_job_heartbeat
  rescue StandardError => e
    Rails.logger.warn("[RollingAucJob] Unexpected error: #{e.message}")
  end

  private

  # Trapezoidal AUC-ROC — O(n log n) sort + O(n) walk.
  #
  # Algorithm:
  #   1. Sort (label, score) pairs by descending score.
  #   2. Walk the list. For each positive (label == 1) increment tp.
  #      For each negative, the current tp covers the strip from prev_fp to fp+1
  #      on the ROC curve — add tp * strip_width / (n_pos * n_neg).
  #   3. After the loop, flush any remaining tp accumulated at the last negative.
  #
  # Returns a value in [0.0, 1.0]. Returns 0.5 if all labels are the same
  # (degenerate case — AUC is undefined, 0.5 is the random baseline).
  def calculate_auc_roc(y_true, y_score)
    n_pos = y_true.count(1).to_f
    n_neg = y_true.count(0).to_f
    return 0.5 if n_pos.zero? || n_neg.zero?

    sorted = y_true.zip(y_score).sort_by { |_, score| -score }

    tp = 0; fp = 0; prev_fp = 0; auc = 0.0

    sorted.each do |label, _|
      if label == 1
        tp += 1
      else
        # Accumulate trapezoid area for the strip [prev_fp..fp]
        auc += tp.to_f * (fp - prev_fp + 1) / (n_pos * n_neg)
        prev_fp = fp
        fp      += 1
      end
    end

    # Flush any remaining tp after the last negative
    auc += tp.to_f * (fp - prev_fp) / (n_pos * n_neg) if fp > prev_fp

    [auc, 1.0].min
  end

  def persist_metrics(auc:, n:, mean_prob:)
    Sidekiq.redis { |r| r.call('SET', 'ml:metrics:rolling_auc',   auc.to_s) }
    Sidekiq.redis { |r| r.call('SET', 'ml:metrics:n_predictions', n.to_s) }
    Sidekiq.redis { |r| r.call('SET', 'ml:metrics:mean_win_prob', mean_prob.to_s) }
  rescue StandardError => e
    Rails.logger.warn("[RollingAucJob] Failed to persist metrics to Redis: #{e.message}")
  end

  def emit_alerts(auc:, mean_prob:, n:)
    if auc < 0.51
      Rails.logger.warn("[RollingAucJob] ML rolling AUC degraded: #{auc} (n=#{n})")
    end

    if mean_prob < 0.48 || mean_prob > 0.58
      Rails.logger.warn("[RollingAucJob] ML win prob drift: mean=#{mean_prob} (n=#{n})")
    end
  end
end
