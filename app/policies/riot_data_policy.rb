# frozen_string_literal: true

# Authorization policy for Riot API data access
class RiotDataPolicy < ApplicationPolicy
  def manage?
    user.admin_or_owner?
  end

  # Scope class for filtering resources based on authorization rules
  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
