# frozen_string_literal: true

module Manager
  module Controllers
    # Manages contracts between an organization and its players or staff.
    #
    # All actions require owner, admin, or manager role. Coaches may view
    # individual contract records for their players via ContractPolicy#show?.
    # Financial data is not accessible to coach, analyst, or viewer roles.
    #
    # @example List contracts expiring within 30 days
    #   GET /api/v1/manager/contracts/expiring?days=30
    #
    # @example Activate a draft contract
    #   POST /api/v1/manager/contracts/:id/activate
    class ContractsController < Api::V1::BaseController
      before_action :require_manager_access!
      before_action -> { require_tier_feature!(:contracts_basic) }
      before_action :set_contract, only: %i[show update destroy activate terminate renew]
      after_action  :verify_authorized

      # GET /api/v1/manager/contracts
      def index
        authorize Contract, :index?, policy_class: Manager::ContractPolicy
        scoped = organization_scoped(Contract).includes(:player, :staff_member, :bonuses)
        contracts = Manager::ContractQuery.new(scoped, params).call
        result = paginate(contracts)
        render_success({
                         contracts: Manager::ContractSerializer.render_as_hash(result[:data]),
                         pagination: result[:pagination]
                       })
      end

      # GET /api/v1/manager/contracts/:id
      def show
        authorize @contract, policy_class: Manager::ContractPolicy
        render_success(
          { contract: Manager::ContractSerializer.render_as_hash(@contract) }
        )
      end

      # POST /api/v1/manager/contracts
      def create
        authorize Contract, :create?, policy_class: Manager::ContractPolicy
        contract = organization_scoped(Contract).new(contract_params)
        contract.created_by = current_user
        contract.save!
        log_user_action(action: 'create', entity_type: 'Contract', entity_id: contract.id)
        render_created(
          { contract: Manager::ContractSerializer.render_as_hash(contract) }
        )
      end

      # PATCH /api/v1/manager/contracts/:id
      def update
        authorize @contract, policy_class: Manager::ContractPolicy
        @contract.update!(contract_params.merge(updated_by: current_user))
        log_user_action(action: 'update', entity_type: 'Contract', entity_id: @contract.id)
        render_success(
          { contract: Manager::ContractSerializer.render_as_hash(@contract) }
        )
      end

      # DELETE /api/v1/manager/contracts/:id
      def destroy
        authorize @contract, policy_class: Manager::ContractPolicy
        @contract.soft_delete!
        log_user_action(action: 'destroy', entity_type: 'Contract', entity_id: @contract.id)
        render_deleted(message: 'Contract deleted')
      end

      # POST /api/v1/manager/contracts/:id/activate
      def activate
        authorize @contract, policy_class: Manager::ContractPolicy
        @contract.update!(status: 'active', signed_at: Date.current, updated_by: current_user)
        log_user_action(action: 'activate', entity_type: 'Contract', entity_id: @contract.id)
        render_success(
          { contract: Manager::ContractSerializer.render_as_hash(@contract) }
        )
      end

      # POST /api/v1/manager/contracts/:id/terminate
      def terminate
        authorize @contract, policy_class: Manager::ContractPolicy
        termination_notes = [@contract.notes, params[:reason]].compact.join("\n")
        @contract.update!(
          status: 'terminated',
          terminated_at: Date.current,
          updated_by: current_user,
          notes: termination_notes
        )
        log_user_action(
          action: 'terminate',
          entity_type: 'Contract',
          entity_id: @contract.id,
          old_values: { status: 'active' },
          new_values: { status: 'terminated' }
        )
        render_success(
          { contract: Manager::ContractSerializer.render_as_hash(@contract) }
        )
      end

      # POST /api/v1/manager/contracts/:id/renew
      def renew
        authorize @contract, policy_class: Manager::ContractPolicy
        renewal = Manager::ContractRenewalService.new(@contract, renewal_params, current_user).call
        log_user_action(action: 'renew', entity_type: 'Contract', entity_id: renewal.id)
        render_created(
          { contract: Manager::ContractSerializer.render_as_hash(renewal) }
        )
      end

      # GET /api/v1/manager/contracts/expiring
      def expiring
        authorize Contract, :expiring?, policy_class: Manager::ContractPolicy
        days      = (params[:days] || 30).to_i.clamp(1, 365)
        contracts = organization_scoped(Contract).expiring(days).includes(:player)
        render_success(
          { contracts: Manager::ContractSerializer.render_as_hash(contracts) }
        )
      end

      # GET /api/v1/manager/contracts/dashboard
      def dashboard
        authorize Contract, :dashboard?, policy_class: Manager::ContractPolicy
        render_success Manager::ContractDashboardService.new(current_organization).call
      end

      private

      def set_contract
        @contract = organization_scoped(Contract).find(params[:id])
      end

      def require_manager_access!
        require_role!('owner', 'admin', 'manager')
      end

      def contract_params
        params.require(:contract).permit(
          :player_id, :staff_member_id, :contract_type, :start_date, :end_date,
          :base_salary, :salary_currency, :salary_period,
          :auto_renewal, :renewal_notice_days, :notes
        )
      end

      def renewal_params
        params.require(:renewal).permit(
          :start_date, :end_date, :base_salary,
          :salary_currency, :salary_period, :notes
        )
      end
    end
  end
end
