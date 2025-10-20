class ProMatchPolicy < ApplicationPolicy
  def index?
    true # All authenticated users can view pro matches
  end

  def show?
    true
  end

  def upcoming?
    true
  end

  def past?
    true
  end

  def refresh?
    # Only organization owners can refresh cache
    user.owner?
  end

  def import?
    # Only coaches and owners can import matches
    user.owner? || user.coach?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
