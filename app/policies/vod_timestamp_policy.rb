class VodTimestampPolicy < ApplicationPolicy
  def index?
    analyst?
  end

  def create?
    analyst?
  end

  def update?
    analyst? && can_access_vod_review?
  end

  def destroy?
    analyst? && can_access_vod_review?
  end

  private

  def can_access_vod_review?
    return false unless record.vod_review

    record.vod_review.organization_id == user.organization_id
  end
end
