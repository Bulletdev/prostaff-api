# frozen_string_literal: true

module Manager
  # Authorization policy for Contract resources.
  #
  # Salary and contract data is restricted to owner, admin, and manager roles.
  # Coaches may view a contract record only when the record is linked to a player
  # (i.e. not a class-level check). All other actions require manager access.
  class ContractPolicy < ApplicationPolicy
    def index?
      owner_admin_or_manager?
    end

    def show?
      (owner_admin_or_manager? || coach_viewing_player_contract?) && same_organization?
    end

    def create?
      owner_admin_or_manager?
    end

    def update?
      owner_admin_or_manager? && same_organization? && record.status.in?(%w[draft pending_signature])
    end

    # Restricted to draft only — terminated and expired contracts are kept for audit.
    def destroy?
      owner_admin_or_manager? && same_organization? && record.status == 'draft'
    end

    def activate?
      owner_admin_or_manager? && same_organization?
    end

    def terminate?
      owner_admin_or_manager? && same_organization?
    end

    def renew?
      owner_admin_or_manager? && same_organization?
    end

    def expiring?
      owner_admin_or_manager?
    end

    def dashboard?
      owner_admin_or_manager?
    end

    private

    def owner_admin_or_manager?
      user.role.in?(%w[owner admin manager])
    end

    def same_organization?
      record.organization_id == user.organization_id
    end

    def coach_viewing_player_contract?
      user.role == 'coach' && record.is_a?(Contract) && record.player_id.present?
    end
  end
end
