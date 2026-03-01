# frozen_string_literal: true

# Authorization policy for ScoutingTarget resources
#
# IMPORTANT: ScoutingTarget is GLOBAL (no organization_id).
# All organizations can view all scouting targets (free agents).
# Organization-specific permissions are handled through ScoutingWatchlist.
class ScoutingTargetPolicy < ApplicationPolicy
  # Anyone with coach+ role can browse global scouting targets
  def index?
    coach?
  end

  # Anyone with coach+ role can view any global scouting target
  def show?
    coach?
  end

  # Anyone with coach+ role can create global scouting targets
  def create?
    coach?
  end

  # Anyone with coach+ role can update global scouting target data
  # Note: This updates the GLOBAL data, not org-specific watchlist data
  def update?
    coach?
  end

  # Only admins can delete global scouting targets
  # This is rarely used since targets are shared across orgs
  def destroy?
    admin?
  end

  # Anyone with coach+ role can sync scouting target data from Riot
  def sync?
    coach?
  end

  # Scope class for filtering resources based on authorization rules
  # Since targets are global, we return all targets for authorized users
  class Scope < Scope
    def resolve
      if %w[coach admin owner].include?(user.role)
        # Return ALL global scouting targets (no org filter)
        scope.all
      else
        scope.none
      end
    end
  end
end
