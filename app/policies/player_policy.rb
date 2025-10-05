class PlayerPolicy < ApplicationPolicy
  def index?
    true # All authenticated users can view players
  end

  def show?
    same_organization?
  end

  def create?
    admin?
  end

  def update?
    admin? && same_organization?
  end

  def destroy?
    owner? && same_organization?
  end

  def stats?
    same_organization?
  end

  def matches?
    same_organization?
  end

  def import?
    admin? && same_organization?
  end

  class Scope < Scope
    def resolve
      scope.where(organization: user.organization)
    end
  end
end
