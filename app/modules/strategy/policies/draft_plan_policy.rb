# frozen_string_literal: true

# Authorization policy for DraftPlan resources
# Allows coaches and above to manage draft strategies
class DraftPlanPolicy < ApplicationPolicy
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

  def analyze?
    coach? && same_organization?
  end

  def activate?
    coach? && same_organization?
  end

  def deactivate?
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
