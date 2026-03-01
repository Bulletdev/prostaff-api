# frozen_string_literal: true

# Authorization policy for VodReview resources
class VodReviewPolicy < ApplicationPolicy
  def index?
    analyst?
  end

  def show?
    analyst? && same_organization?
  end

  def create?
    analyst?
  end

  def update?
    analyst? && same_organization?
  end

  def destroy?
    admin? && same_organization?
  end

  # Scope class for filtering resources based on authorization rules
  class Scope < Scope
    def resolve
      if %w[analyst coach admin owner].include?(user.role)
        scope.where(organization: user.organization)
      else
        scope.none
      end
    end
  end
end
