# frozen_string_literal: true

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

  class Scope < Scope
    def resolve
      scope.where(organization: user.organization)
    end
  end
end
