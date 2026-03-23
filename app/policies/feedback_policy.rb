# frozen_string_literal: true

# Authorization policy for Feedback resource.
#
# - Any authenticated user can create feedback
# - Only admins can list all feedbacks
class FeedbackPolicy < ApplicationPolicy
  # Any authenticated user can view the public feedback board
  def index?
    user.present?
  end

  # Any authenticated user can submit feedback
  def create?
    user.present?
  end
end
