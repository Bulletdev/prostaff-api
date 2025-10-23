# frozen_string_literal: true

class RiotDataPolicy < ApplicationPolicy
  def manage?
    user.admin_or_owner?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
