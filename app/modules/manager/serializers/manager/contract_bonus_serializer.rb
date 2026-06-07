# frozen_string_literal: true

module Manager
  # Serializer for ContractBonus model.
  class ContractBonusSerializer < Blueprinter::Base
    identifier :id

    fields :bonus_type, :trigger, :amount, :currency, :status,
           :achieved_at, :paid_at, :notes, :created_at, :updated_at
  end
end
