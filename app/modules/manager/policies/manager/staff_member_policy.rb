# frozen_string_literal: true

module Manager
  # Authorization policy for StaffMember resources.
  #
  # Managers (owner, admin, manager) can perform all CRUD operations.
  # Coaches can view (index, show) but cannot modify.
  class StaffMemberPolicy < ApplicationPolicy
    def index?
      coach_or_above?
    end

    def show?
      coach_or_above? && same_organization?
    end

    def create?
      owner_admin_or_manager?
    end

    def update?
      owner_admin_or_manager? && same_organization?
    end

    def destroy?
      owner_admin_or_manager? && same_organization?
    end

    private

    def owner_admin_or_manager?
      user.role.in?(%w[owner admin manager])
    end

    def coach_or_above?
      user.role.in?(%w[owner admin manager coach])
    end

    def same_organization?
      record.organization_id == user.organization_id
    end
  end
end
