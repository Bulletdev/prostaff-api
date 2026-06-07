# frozen_string_literal: true

module Manager
  # Authorization policy for Expense resources.
  #
  # Financial data (salary, budget, expense records) must never be accessible
  # to coach, analyst, or viewer roles. All actions require owner, admin, or manager.
  class ExpensePolicy < ApplicationPolicy
    def index?
      owner_admin_or_manager?
    end

    def show?
      owner_admin_or_manager? && same_organization?
    end

    def create?
      owner_admin_or_manager?
    end

    def update?
      owner_admin_or_manager? && same_organization? && record.status == 'pending'
    end

    def destroy?
      owner_admin_or_manager? && same_organization? && record.status == 'pending'
    end

    def approve?
      owner_admin_or_manager? && same_organization?
    end

    def mark_paid?
      owner_admin_or_manager? && same_organization?
    end

    def reject?
      owner_admin_or_manager? && same_organization?
    end

    def salary_summary?
      owner_admin_or_manager?
    end

    def report?
      owner_admin_or_manager?
    end

    def export?
      owner_admin_or_manager?
    end

    private

    def owner_admin_or_manager?
      user.role.in?(%w[owner admin manager])
    end

    def same_organization?
      record.organization_id == user.organization_id
    end
  end
end
