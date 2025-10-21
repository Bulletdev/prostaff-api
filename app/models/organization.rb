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

  private

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