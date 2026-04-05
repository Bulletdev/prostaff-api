# frozen_string_literal: true

# Authorization policy for InhouseQueue.
#
# Read actions (status) are open to all authenticated org members.
# Player actions (join, leave, checkin) are open to authenticated members —
#   the Discord bot calls these using the org's coach token on behalf of players.
# Management actions (open, close, start_checkin, start_session) require coach role.
class InhouseQueuePolicy < ApplicationPolicy
  def status?
    user.present?
  end

  def open?
    coach?
  end

  def join?
    user.present?
  end

  def leave?
    user.present?
  end

  def start_checkin?
    coach?
  end

  def checkin?
    user.present?
  end

  def start_session?
    coach?
  end

  def close?
    coach?
  end
end
