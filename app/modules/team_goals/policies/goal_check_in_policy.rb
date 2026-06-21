# frozen_string_literal: true

# Authorization policy for GoalCheckIn resources.
#
# Check-ins are visible to anyone who can see the parent goal.
# Only managers and coaches can create manual check-ins.
# Check-ins are never deleted (append-only audit trail).
class GoalCheckInPolicy < ApplicationPolicy
  def index?
    same_organization?
  end

  def show?
    same_organization?
  end

  def create?
    return false unless same_organization?

    manager? || coach?
  end

  def destroy?
    false
  end

  class Scope < Scope
    def resolve
      scope.where(organization: user.organization)
    end
  end

  private

  def manager?
    %w[owner admin manager].include?(user.role)
  end

  def coach?
    user.role == 'coach'
  end
end
