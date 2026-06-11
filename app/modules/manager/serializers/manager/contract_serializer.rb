# frozen_string_literal: true

module Manager
  # Serializer for Contract model.
  #
  # Default view includes all contract fields plus computed days_remaining
  # and expiring_soon flag. The :summary view is used when embedding contract
  # data inside player responses (owner/admin only via view: :with_contract).
  class ContractSerializer < Blueprinter::Base
    identifier :id

    fields :contract_type, :status, :start_date, :end_date,
           :base_salary, :salary_currency, :salary_period,
           :auto_renewal, :renewal_notice_days, :signed_at,
           :terminated_at, :notes, :created_at, :updated_at

    field :days_remaining do |contract|
      contract.days_remaining
    end

    field :expiring_soon do |contract|
      contract.expiring_soon?(30)
    end

    association :player, blueprint: PlayerSummarySerializer
    association :bonuses, blueprint: Manager::ContractBonusSerializer

    view :summary do
      fields :status, :end_date, :base_salary, :salary_currency, :salary_period

      field :days_remaining do |contract|
        contract.days_remaining
      end

      association :player, blueprint: PlayerSummarySerializer
    end
  end
end
