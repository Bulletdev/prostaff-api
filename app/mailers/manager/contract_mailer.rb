# frozen_string_literal: true

module Manager
  # Sends contract lifecycle alerts to organization managers.
  #
  # Recipients: users with role owner/admin/manager in the contract's organization.
  # In development, CONTRACT_ALERT_RECIPIENTS overrides this list so you can direct
  # alerts to test inboxes without touching production user records.
  #
  # @example Manual trigger from Rails console
  #   Manager::ContractMailer.expiry_alert(contract, 30).deliver_now
  class ContractMailer < ApplicationMailer
    # @param contract [Contract] the expiring contract (with :player and :organization preloaded)
    # @param days [Integer] which threshold triggered this alert (e.g. 30, 14, 7)
    def expiry_alert(contract, days)
      @contract      = contract
      @player        = contract.player
      @organization  = contract.organization
      @days          = days
      @end_date      = contract.end_date.strftime('%d/%m/%Y')
      @base_salary   = format_salary(contract)
      @frontend_url  = ENV.fetch('PROSTAFF_URL', 'https://app.prostaff.gg')
      @urgency       = urgency_level(days)

      mail(
        to: recipients,
        subject: "[ProStaff] Contrato expirando em #{days} dias — #{@player.summoner_name}"
      ) do |format|
        format.html { render layout: false }
        format.text
      end
    end

    private

    def recipients
      override = ENV['CONTRACT_ALERT_RECIPIENTS']
      return override.split(',').map(&:strip) if override.present?

      User.where(organization: @organization, role: %w[owner admin manager])
          .pluck(:email)
          .presence || [ENV.fetch('MAILER_FROM_EMAIL', 'noreply@prostaff.gg')]
    end

    def format_salary(contract)
      period_label = { 'monthly' => 'mês', 'weekly' => 'semana', 'per_event' => 'evento' }
                     .fetch(contract.salary_period, contract.salary_period)
      "R$ #{format('%.0f', contract.base_salary)}/#{period_label}"
    end

    def urgency_level(days)
      return :critical if days <= 7
      return :urgent   if days <= 14
      return :warning  if days <= 30

      :preventive
    end
  end
end
