# frozen_string_literal: true

module Manager
  # Scans active contracts and enqueues expiry alert emails at standard thresholds.
  #
  # Runs daily via Sidekiq Scheduler. Uses a +-1 day window instead of an exact
  # date match so the job tolerates a single day of cron downtime without skipping
  # a threshold.
  #
  # Delegation pattern: this job only discovers which contracts need alerts and
  # enqueues ContractAlertMailerJob for each. The mailer job sets the idempotency
  # flag (metadata[alert_key]) AFTER successful delivery, so SMTP failures trigger
  # Sidekiq retries without silently marking a contract as alerted.
  #
  # @example Manual trigger from Rails console
  #   Manager::ContractExpiryAlertJob.new.perform
  class ContractExpiryAlertJob
    include Sidekiq::Job

    sidekiq_options queue: 'default', retry: 3

    THRESHOLDS = [90, 60, 30, 14, 7].freeze

    # Iterates over each configured threshold, queries contracts whose end_date
    # falls within a +-1 day window of that threshold, and flags each one.
    # @return [void]
    def perform
      THRESHOLDS.each do |days|
        process_threshold(days)
      end
    end

    private

    # @param days [Integer] threshold in days (e.g. 30 means "expiring in ~30 days")
    # @return [void]
    def process_threshold(days)
      target    = Date.current + days.days
      window    = (target - 1.day)..(target + 1.day)
      alert_key = "alerted_#{days}d"

      contracts_due(window, alert_key).find_each do |contract|
        enqueue_alert(contract, alert_key, days)
      end
    end

    # Returns active contracts expiring in the given window that have not yet been
    # flagged for this threshold.
    # @param window [Range<Date>]
    # @param alert_key [String]
    # @return [ActiveRecord::Relation]
    def contracts_due(window, alert_key)
      Contract.active
              .where(end_date: window)
              .where.not('metadata @> ?', { alert_key => true }.to_json)
              .includes(:organization, :player)
    end

    # Enqueues ContractAlertMailerJob for the given contract/threshold pair.
    # The mailer job sets the idempotency flag after successful delivery.
    # @param contract [Contract]
    # @param alert_key [String]
    # @param days [Integer]
    # @return [void]
    def enqueue_alert(contract, alert_key, days)
      Rails.logger.info(
        "[ContractExpiryAlertJob] enqueuing alert contract=#{contract.id} days=#{days}"
      )
      Manager::ContractAlertMailerJob.perform_async(contract.id, days, alert_key)
    rescue StandardError => e
      Rails.logger.error(
        "[ContractExpiryAlertJob] enqueue failed contract=#{contract.id} error=#{e.message}"
      )
    end
  end
end
