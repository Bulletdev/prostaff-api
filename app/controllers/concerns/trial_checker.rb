# frozen_string_literal: true

# TrialChecker Concern
#
# Checks if the organization's trial has expired and blocks access if needed.
# This concern should be included in controllers that require active subscription.
#
# Usage:
#   class SomeController < ApplicationController
#     include TrialChecker
#     before_action :check_trial_access
#   end
module TrialChecker
  extend ActiveSupport::Concern

  included do
    # Override this in controllers where trial access should be blocked
    # By default, we allow trial users to access most features
  end

  # Check if organization has active access (paid or valid trial)
  # Blocks access if trial has expired
  def check_trial_access
    return unless current_organization

    # Auto-expire trials that have passed their expiration date
    if current_organization.trial_expired?
      current_organization.expire_trial! unless current_organization.subscription_status == 'expired'
    end

    # Block access if subscription is expired
    if current_organization.subscription_status == 'expired'
      render_trial_expired
      return false
    end

    true
  end

  # Check if trial is expiring soon (within 3 days)
  def trial_expiring_soon?
    return false unless current_organization&.on_trial?

    current_organization.trial_days_remaining <= 3
  end

  # Add trial warning to response headers
  def add_trial_warning_headers
    return unless current_organization&.on_trial?

    days_remaining = current_organization.trial_days_remaining
    response.headers['X-Trial-Days-Remaining'] = days_remaining.to_s
    response.headers['X-Trial-Expires-At'] = current_organization.trial_expires_at.iso8601
  end

  private

  def render_trial_expired
    render json: {
      error: {
        code: 'TRIAL_EXPIRED',
        message: 'Seu período de teste expirou. Por favor, faça upgrade para continuar usando o ProStaff.',
        details: {
          trial_started_at: current_organization.trial_started_at,
          trial_expired_at: current_organization.trial_expires_at,
          subscription_status: current_organization.subscription_status,
          upgrade_url: '/settings/billing'
        }
      }
    }, status: :payment_required # 402
  end
end
