# frozen_string_literal: true

module Manager
  # Computes contract summary statistics for the manager dashboard.
  #
  # Queries the organization's contracts and returns aggregate counts, the
  # total monthly payroll (normalized across salary periods), and a list of
  # upcoming renewals within 60 days.
  #
  # @example
  #   Manager::ContractDashboardService.new(current_organization).call
  #   # => { total_active: 5, expiring_30: 2, expiring_60: 3, expired: 1,
  #   #      total_monthly_salary: 45000.0, upcoming_renewals: [...] }
  class ContractDashboardService
    def initialize(organization)
      @org = organization
    end

    def call
      contracts = Contract.unscoped.where(organization: @org).where(deleted_at: nil)

      {
        total_contracts: contracts.count,
        active_contracts: contracts.active.count,
        expiring_soon: contracts.expiring(90).count,
        expiring_60: contracts.expiring(60).count,
        expired: contracts.expired.count,
        total_monthly_payroll: monthly_equivalent(contracts.active.to_a),
        contracts_by_status: contracts.group(:status).count,
        upcoming_renewals: build_upcoming_renewals(contracts)
      }
    end

    private

    def build_upcoming_renewals(contracts)
      contracts.expiring(60).includes(:player).map do |c|
        {
          player_name: c.player.summoner_name,
          end_date: c.end_date,
          days_remaining: c.days_remaining,
          salary: c.base_salary
        }
      end
    end

    # Normalizes each contract's salary to a monthly equivalent before summing.
    # weekly contracts are multiplied by 4; per_event contracts are excluded
    # from recurring payroll (treated as 0).
    # @param contracts [Array<Contract>]
    # @return [Float]
    def monthly_equivalent(contracts)
      contracts.sum { |c| monthly_equiv(c) }
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
