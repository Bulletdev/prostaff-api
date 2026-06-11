# frozen_string_literal: true

module Manager
  # Authorization policy for BudgetAllocation resources.
  #
  # All budget actions are restricted to owner, admin, and manager roles.
  # Financial data must not be accessible to coach, analyst, or viewer roles.
  class BudgetAllocationPolicy < ApplicationPolicy
    def index?
      owner_admin_or_manager?
    end

    def show?
      owner_admin_or_manager?
    end

    def create?
      owner_admin_or_manager?
    end

    def update?
      owner_admin_or_manager?
    end

    def destroy?
      owner_admin_or_manager?
    end

    def summary?
      owner_admin_or_manager?
    end

    private

    def owner_admin_or_manager?
      user.role.in?(%w[owner admin manager])
    end
  end
end
