# frozen_string_literal: true

# Represents a League of Legends esports organization
#
# Organizations are the top-level entities in the system. Each organization
# has players, matches, schedules, and is associated with a specific tier
# that determines available features and limits.
#
# The tier system controls access to features:
# - tier_3_amateur: Basic features for amateur teams
# - tier_2_semi_pro: Advanced features including scrim tracking
# - tier_1_professional: Full feature set with competitive data
#
# @attr [String] name Organization's full name (required)
# @attr [String] slug URL-friendly unique identifier (auto-generated)
# @attr [String] region Server region (BR, NA, EUW, etc.)
# @attr [String] tier Access tier determining available features
# @attr [String] subscription_plan Current subscription plan
# @attr [String] subscription_status Subscription status: active, inactive, trial, or expired
#
# @example Creating a new organization
#   org = Organization.create!(
#     name: "T1 Esports",
#     region: "KR",
#     tier: "tier_1_professional"
#   )
#
# @example Checking feature access
#   org.can_access_scrims? # => true for tier_2+
#   org.can_access_competitive_data? # => true for tier_1 only
#
class Organization < ApplicationRecord
  # Concerns
  include TierFeatures
  include Constants

  # Associations
  has_many :users, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :scouting_targets, dependent: :destroy
  has_many :schedules, dependent: :destroy
  has_many :vod_reviews, dependent: :destroy
  has_many :team_goals, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  # New tier-based associations
  has_many :scrims, dependent: :destroy
  has_many :competitive_matches, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :region, presence: true, inclusion: { in: Constants::REGIONS }
  validates :tier, inclusion: { in: Constants::Organization::TIERS }, allow_blank: true
  validates :subscription_plan, inclusion: { in: Constants::Organization::SUBSCRIPTION_PLANS }, allow_blank: true
  validates :subscription_status, inclusion: { in: Constants::Organization::SUBSCRIPTION_STATUSES }, allow_blank: true

  # Callbacks
  before_validation :generate_slug, on: :create

  # Scopes
  scope :by_region, ->(region) { where(region: region) }
  scope :by_tier, ->(tier) { where(tier: tier) }
  scope :active_subscription, -> { where(subscription_status: 'active') }
  scope :trial_active, -> { where(subscription_status: 'trial').where('trial_expires_at > ?', Time.current) }
  scope :trial_expired, -> { where(subscription_status: 'trial').where('trial_expires_at <= ?', Time.current) }

  # Callbacks for trial management
  before_create :set_trial_period, if: -> { subscription_plan.blank? || subscription_plan == 'free' }
  before_save :check_trial_expiration, if: :trial_expires_at_changed?

  # Trial management methods

  # Check if organization is on an active trial
  # @return [Boolean]
  def on_trial?
    subscription_status == 'trial' && trial_expires_at.present? && trial_expires_at > Time.current
  end

  # Check if trial has expired
  # @return [Boolean]
  def trial_expired?
    subscription_status == 'trial' && trial_expires_at.present? && trial_expires_at <= Time.current
  end

  # Get remaining trial days
  # @return [Integer] Days remaining, 0 if expired or not on trial
  def trial_days_remaining
    return 0 unless on_trial?

    ((trial_expires_at - Time.current) / 1.day).ceil
  end

  # Check if organization has active access (paid or valid trial)
  # @return [Boolean]
  def has_active_access?
    subscription_status == 'active' || on_trial?
  end

  # Expire the trial and revoke access
  def expire_trial!
    update!(
      subscription_status: 'expired',
      subscription_plan: 'free'
    )
  end

  # Activate a paid subscription
  # @param plan [String] The subscription plan
  def activate_subscription!(plan)
    update!(
      subscription_status: 'active',
      subscription_plan: plan,
      trial_expires_at: nil # Clear trial expiration
    )
  end

  private

  # Sets trial period for new free/trial organizations
  def set_trial_period
    self.subscription_status = 'trial'
    self.subscription_plan = 'free'
    self.trial_started_at = Time.current
    self.trial_expires_at = 14.days.from_now # 14-day trial
  end

  # Automatically expire trial if expiration date has passed
  def check_trial_expiration
    if trial_expires_at.present? && trial_expires_at <= Time.current
      self.subscription_status = 'expired'
    end
  end

  def generate_slug
    return if slug.present?

    base_slug = name.parameterize
    counter = 1
    generated_slug = base_slug

    while ::Organization.exists?(slug: generated_slug)
      generated_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = generated_slug
  end
end
