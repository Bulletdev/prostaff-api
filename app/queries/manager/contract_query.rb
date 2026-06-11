# frozen_string_literal: true

module Manager
  # Query object for filtering and sorting Contract records.
  #
  # Accepts a pre-scoped ActiveRecord relation and applies filter params.
  # Supported params: status, contract_type, player_id, expiring_in,
  # sort_by (end_date|start_date|base_salary), sort_order (asc|desc).
  #
  # @example Usage in controller
  #   contracts = Manager::ContractQuery.new(
  #     organization_scoped(Contract).includes(:player, :bonuses),
  #     params
  #   ).call
  class ContractQuery
    SORTABLE = %w[end_date start_date base_salary].freeze

    def initialize(scope, params)
      @scope  = scope
      @params = params
    end

    def call
      apply_filters(@scope)
    end

    private

    def apply_filters(scope)
      scope = filter_by_status(scope)
      scope = filter_by_type(scope)
      scope = filter_by_player(scope)
      scope = filter_by_expiring(scope)
      sort(scope)
    end

    def filter_by_status(scope)
      return scope unless @params[:status].present?

      scope.where(status: @params[:status])
    end

    def filter_by_type(scope)
      return scope unless @params[:contract_type].present?

      scope.where(contract_type: @params[:contract_type])
    end

    def filter_by_player(scope)
      return scope unless @params[:player_id].present?

      scope.where(player_id: @params[:player_id])
    end

    def filter_by_expiring(scope)
      return scope unless @params[:expiring_in].present?

      days = @params[:expiring_in].to_i.clamp(1, 365)
      scope.expiring(days)
    end

    def sort(scope)
      column = SORTABLE.include?(@params[:sort_by]) ? @params[:sort_by] : 'end_date'
      order  = @params[:sort_order] == 'desc' ? :desc : :asc
      scope.order(column => order)
    end
  end
end
