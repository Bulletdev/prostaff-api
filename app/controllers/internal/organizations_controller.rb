# frozen_string_literal: true

module Internal
  # Internal API controller for updating organization tier and subscription data.
  # Called exclusively by the ProPay payment gateway via a signed internal JWT.
  class OrganizationsController < ActionController::API
    include InternalServiceAuthenticatable

    ALLOWED_TIERS = Constants::Organization::TIERS
    ALLOWED_PLANS = Constants::Organization::SUBSCRIPTION_PLANS
    ALLOWED_STATUSES = Constants::Organization::SUBSCRIPTION_STATUSES

    def update_tier
      user = User.find_by(id: params[:user_id])
      return render json: { error: 'user not found' }, status: :not_found unless user

      org = user.organization
      return render json: { error: 'organization not found' }, status: :not_found unless org

      tier   = params[:tier].to_s
      plan   = params[:subscription_plan].to_s
      status = params[:subscription_status].to_s

      unless ALLOWED_TIERS.include?(tier)
        return render json: { error: "invalid tier: #{tier}" }, status: :unprocessable_entity
      end

      unless ALLOWED_PLANS.include?(plan)
        return render json: { error: "invalid subscription_plan: #{plan}" }, status: :unprocessable_entity
      end

      unless ALLOWED_STATUSES.include?(status)
        return render json: { error: "invalid subscription_status: #{status}" }, status: :unprocessable_entity
      end

      org.update!(tier: tier, subscription_plan: plan, subscription_status: status)

      render json: {
        data: {
          id: org.id,
          tier: org.tier,
          subscription_plan: org.subscription_plan,
          subscription_status: org.subscription_status
        }
      }
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
