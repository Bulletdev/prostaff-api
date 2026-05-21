# frozen_string_literal: true

# Authorization policy for Player resources
class PlayerPolicy < ApplicationPolicy
  def index?
    true # All authenticated users can view players
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
    owner? && same_organization?
  end

  def stats?
    same_organization?
  end

  def matches?
    same_organization?
  end

  def import?
    coach?
  end

  def sync_from_riot?
    coach? && same_organization?
  end

  def bulk_sync?
    coach?
  end

  # Scope class for filtering resources based on authorization rules
  class Scope < Scope
    def resolve
      scope.where(organization: user.organization)
    end
  end
end
