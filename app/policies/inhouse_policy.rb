# frozen_string_literal: true

# Authorization policy for Inhouse sessions.
#
# Read actions (index, active) are open to all authenticated org members.
# Destructive/write actions require coach role or above.
# Multi-tenant isolation is enforced at the controller level via current_organization scope.
class InhousePolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def active?
    user.present?
  end

  def ladder?
    user.present?
  end

  def sessions?
    user.present?
  end

  def create?
    coach?
  end

  def join?
    coach?
  end

  def balance_teams?
    coach?
  end

  def start_draft?
    coach?
  end

  def captain_pick?
    coach?
  end

  def start_game?
    coach?
  end

  def record_game?
    coach?
  end

  def close?
    coach?
  end
end
