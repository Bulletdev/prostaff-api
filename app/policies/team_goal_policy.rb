class TeamGoalPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    same_organization?
  end

  def create?
    coach?
  end

  def update?
    can_update?
  end

  def destroy?
    admin? && same_organization?
  end

  private

  def can_update?
    return false unless same_organization?

    # Owners/admins can update any goal
    return true if admin?

    # Coaches can update goals
    return true if coach?

    # Users can update goals assigned to them
    record.assigned_to_id == user.id
  end

  class Scope < Scope
    def resolve
      scope.where(organization: user.organization)
    end
  end
end
