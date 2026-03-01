# frozen_string_literal: true

# Authorization policy for TacticalBoard resources
# Allows coaches and above to manage tactical boards
class TacticalBoardPolicy < ApplicationPolicy
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

  def statistics?
    coach? && same_organization?
  end

  # Scope class for filtering resources based on authorization rules
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
