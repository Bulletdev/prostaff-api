# frozen_string_literal: true

module Manager
  # Delivers a single contract expiry alert email and marks the contract as alerted.
  #
  # Accepts primitives only — no ActiveRecord objects — to avoid GlobalID
  # deserialization failures when the Sidekiq worker process resolves constants
  # differently from the web process. The contract is reloaded from the DB inside
  # the job.
  #
  # The idempotency flag (metadata[alert_key]) is written AFTER successful delivery
  # so that Sidekiq retries on SMTP failure will re-attempt without the contract
  # being permanently skipped.
  #
  # @example Manual trigger
  #   Manager::ContractAlertMailerJob.perform_async(contract.id, 14, 'alerted_14d')
  class ContractAlertMailerJob
    include Sidekiq::Job

    sidekiq_options queue: 'mailers', retry: 5

    # @param contract_id [String] UUID of the contract
    # @param days [Integer] threshold that triggered this alert
    # @param alert_key [String] metadata key for idempotency (e.g. 'alerted_14d')
    def perform(contract_id, days, alert_key)
      contract = Contract.find_by(id: contract_id)
      return unless contract
      return if contract.metadata[alert_key]

      Current.organization_id = contract.organization_id
      contract_with_assoc = Contract.includes(:player, :organization).find(contract_id)

      Manager::ContractMailer.expiry_alert(contract_with_assoc, days).deliver_now
      contract.update_columns(metadata: contract.metadata.merge(alert_key => true))
    ensure
      Current.organization_id = nil
    end
  end
end
