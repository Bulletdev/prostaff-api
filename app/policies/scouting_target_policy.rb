class ScoutingTargetPolicy < ApplicationPolicy
  def index?
    coach?
  end

  def show?
    coach? && same_organization?
  end

  def create?
    coach?
  end

  def update?
    coach? && same_organization?
  end

  def destroy?
    admin? && same_organization?
  end

  def sync?
    coach? && same_organization?
  end

  class Scope < Scope
    def resolve
      if %w[coach admin owner].include?(user.role)
        scope.where(organization: user.organization)
      else
        scope.none
      end
    end
  end
end
