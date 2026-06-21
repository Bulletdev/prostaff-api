# frozen_string_literal: true

module Manager
  module Controllers
    # Manages bonus clauses attached to contracts.
    #
    # Nested under contracts: /api/v1/manager/contracts/:contract_id/bonuses
    # All actions require owner, admin, or manager role.
    class ContractBonusesController < Api::V1::BaseController
      before_action :require_manager_access!
      before_action :set_contract
      before_action :set_bonus, only: %i[show update destroy]
      after_action  :verify_authorized

      # GET /api/v1/manager/contracts/:contract_id/bonuses
      def index
        authorize @contract, :show?, policy_class: Manager::ContractPolicy
        bonuses = @contract.bonuses.order(created_at: :desc)
        render_success({
          bonuses: Manager::ContractBonusSerializer.render_as_hash(bonuses)
        })
      end

      # POST /api/v1/manager/contracts/:contract_id/bonuses
      def create
        authorize @contract, :update?, policy_class: Manager::ContractPolicy
        bonus = @contract.bonuses.new(bonus_params)
        bonus.organization = current_organization
        bonus.save!
        log_user_action(action: 'create', entity_type: 'ContractBonus', entity_id: bonus.id)
        render_created({
          bonus: Manager::ContractBonusSerializer.render_as_hash(bonus)
        })
      end

      # GET /api/v1/manager/contracts/:contract_id/bonuses/:id
      def show
        authorize @contract, :show?, policy_class: Manager::ContractPolicy
        render_success({
          bonus: Manager::ContractBonusSerializer.render_as_hash(@bonus)
        })
      end

      # PATCH /api/v1/manager/contracts/:contract_id/bonuses/:id
      def update
        authorize @contract, :update?, policy_class: Manager::ContractPolicy
        @bonus.update!(bonus_params)
        log_user_action(action: 'update', entity_type: 'ContractBonus', entity_id: @bonus.id)
        render_success({
          bonus: Manager::ContractBonusSerializer.render_as_hash(@bonus)
        })
      end

      # DELETE /api/v1/manager/contracts/:contract_id/bonuses/:id
      def destroy
        authorize @contract, :destroy?, policy_class: Manager::ContractPolicy
        @bonus.destroy!
        log_user_action(action: 'destroy', entity_type: 'ContractBonus', entity_id: @bonus.id)
        render_deleted(message: 'Bonus deleted')
      end

      private

      def set_contract
        @contract = organization_scoped(Contract).find(params[:contract_id])
      end

      def set_bonus
        @bonus = @contract.bonuses.find(params[:id])
      end

      def require_manager_access!
        require_role!('owner', 'admin', 'manager')
      end

      def bonus_params
        params.require(:bonus).permit(
          :bonus_type, :trigger, :amount, :currency,
          :status, :achieved_at, :paid_at, :notes
        )
      end
    end
  end
end
