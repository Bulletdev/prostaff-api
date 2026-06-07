# frozen_string_literal: true

module Manager
  # Handles the contract renewal workflow.
  #
  # Marks the original contract as 'renewed' and creates a new draft contract
  # linked via renewed_from_id. Both operations are wrapped in a transaction
  # to ensure atomicity.
  #
  # @example
  #   renewal = Manager::ContractRenewalService.new(contract, renewal_params, current_user).call
  #   # => new Contract with status: 'draft' and renewed_from_id set
  class ContractRenewalService
    def initialize(original, params, user)
      @original = original
      @params   = params
      @user     = user
    end

    def call
      ActiveRecord::Base.transaction do
        @original.update!(status: 'renewed', updated_by: @user)
        build_renewal_contract
      end
    end

    private

    def build_renewal_contract
      Contract.create!(
        organization: @original.organization,
        player: @original.player,
        contract_type: @original.contract_type,
        status: 'draft',
        created_by: @user,
        renewed_from_id: @original.id,
        start_date: @params[:start_date],
        end_date: @params[:end_date],
        base_salary: @params[:base_salary] || @original.base_salary,
        salary_currency: @params[:salary_currency] || @original.salary_currency,
        salary_period: @params[:salary_period] || @original.salary_period,
        notes: @params[:notes]
      )
    end
  end
end
