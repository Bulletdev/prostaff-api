# frozen_string_literal: true

module Manager
  # Computes the current payroll summary for an organization.
  #
  # Reads from active contracts (not from player cache fields). All salary amounts
  # are normalized to a monthly equivalent before summing the total payroll.
  # weekly contracts are multiplied by 4; per_event contracts are excluded.
  #
  # @example
  #   Manager::SalarySummaryService.new(current_organization).call
  #   # => { total_monthly_payroll: 45000.0, player_count: 5, players: [...] }
  class SalarySummaryService
    def initialize(organization)
      @org = organization
    end

    def call
      active_contracts = Contract.unscoped
                                 .active
                                 .where(organization: @org)

      player_ids = active_contracts.pluck(:player_id)
      players_by_id = Player.unscoped.where(id: player_ids).index_by(&:id)
      contracts_array = active_contracts.to_a

      {
        total_monthly_payroll: normalize_to_monthly(contracts_array),
        payroll_by_currency: payroll_by_currency(contracts_array),
        player_count: active_contracts.count,
        players: build_player_list(contracts_array, players_by_id)
      }
    end

    private

    def build_player_list(contracts, players_by_id)
      contracts.map { |c| player_entry(c, players_by_id[c.player_id]) }
    end

    def player_entry(contract, player)
      {
        player_id: contract.player_id,
        player_name: player&.summoner_name,
        role: player&.role,
        salary: contract.base_salary,
        salary_period: contract.salary_period,
        monthly_equiv: monthly_equiv(contract),
        currency: contract.salary_currency,
        contract_ends: contract.end_date,
        days_remaining: contract.days_remaining
      }
    end

    def normalize_to_monthly(contracts)
      contracts.sum { |c| monthly_equiv(c) }
    end

    def payroll_by_currency(contracts)
      contracts.each_with_object({}) do |c, hash|
        currency = c.salary_currency
        hash[currency] = (hash[currency] || 0) + monthly_equiv(c)
      end
    end

    def monthly_equiv(contract)
      case contract.salary_period
      when 'weekly'    then contract.base_salary * 4
      when 'per_event' then 0
      else                  contract.base_salary
      end
    end
  end
end
