# frozen_string_literal: true

# Authorization policy for Schedule resources
class SchedulePolicy < ApplicationPolicy
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
    coach? && same_organization?
  end

  def destroy?
    admin? && same_organization?
  end

  # Scope class for filtering resources based on authorization rules
  class Scope < Scope
    def resolve
      scope.where(organization: user.organization)
    end
  end
end
