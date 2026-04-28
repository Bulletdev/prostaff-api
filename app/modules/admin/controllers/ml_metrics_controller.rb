# frozen_string_literal: true

module Admin
  module Controllers
    # Exposes rolling ML quality metrics to admin/staff users.
    #
    # All values are written to Redis by RollingAucJob (runs nightly at 03:00 UTC)
    # and by MlHealthCheckJob (reads circuit-breaker state).
    #
    # GET /api/v1/admin/ml-metrics
    #
    # Response:
    #   {
    #     rolling_auc:    Float | null,   # AUC-ROC over last 200 settled predictions
    #     mean_win_prob:  Float | null,   # mean predicted probability
    #     n_predictions:  Integer | null, # sample size used for last AUC calculation
    #     circuit_open:   Boolean         # true when ML circuit breaker is currently open
    #   }
    #
    # Returns 200 even when metrics have not been calculated yet (fields will be null).
    class MlMetricsController < Api::V1::BaseController
      before_action :require_admin_or_staff!

      # GET /api/v1/admin/ml-metrics
      def index
        metrics = read_metrics_from_redis
        render_success(metrics)
      rescue StandardError => e
        Rails.logger.warn("[Admin::MlMetricsController] Failed to read metrics: #{e.message}")
        render_success({
                         rolling_auc:   nil,
                         mean_win_prob: nil,
                         n_predictions: nil,
                         circuit_open:  false
                       })
      end

      private

      def require_admin_or_staff!
        return if current_user&.admin? || current_user&.owner? || current_user&.staff?

        render_error(
          message: 'Admin or staff access required',
          code: 'FORBIDDEN',
          status: :forbidden
        )
      end

      def read_metrics_from_redis
        Sidekiq.redis do |r|
          auc_raw   = r.call('GET', 'ml:metrics:rolling_auc')
          n_raw     = r.call('GET', 'ml:metrics:n_predictions')
          mean_raw  = r.call('GET', 'ml:metrics:mean_win_prob')
          open_until = r.call('GET', MlServiceClient::CIRCUIT_OPEN_UNTIL_KEY).to_i

          {
            rolling_auc:   auc_raw  ? auc_raw.to_f  : nil,
            mean_win_prob: mean_raw ? mean_raw.to_f : nil,
            n_predictions: n_raw    ? n_raw.to_i    : nil,
            circuit_open:  open_until > Time.now.to_i
          }
        end
      end
    end
  end
end
