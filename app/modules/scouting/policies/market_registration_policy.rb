# frozen_string_literal: true

# Authorization policy for MarketRegistration resources.
#
# MarketRegistration records are global public data (Leaguepedia GCD).
# They have no organization_id — all authenticated users can read them.
# Only admins/owners can mutate them (data is maintained by the nightly sync job).
class MarketRegistrationPolicy < ApplicationPolicy
  # Any authenticated user can browse market registrations.
  def index?
    coach?
  end

  # Any authenticated user can view a single market registration.
  def show?
    coach?
  end

  # Only admins/owners can create records (normally done by the sync job).
  def create?
    admin?
  end

  # Only admins/owners can update records (normally done by the sync job).
  def update?
    admin?
  end

  # Only admins/owners can delete records.
  def destroy?
    admin?
  end

  # Scope — market registrations are global, return all for authorized users.
  class Scope < Scope
    def resolve
      if %w[coach manager analyst admin owner].include?(user.role)
        scope.all
      else
        scope.none
      end
    end
  end
end
