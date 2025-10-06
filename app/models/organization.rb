class Organization < ApplicationRecord
  # Associations
  has_many :users, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :scouting_targets, dependent: :destroy
  has_many :schedules, dependent: :destroy
  has_many :vod_reviews, dependent: :destroy
  has_many :team_goals, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :region, presence: true, inclusion: { in: %w[BR NA EUW KR EUNE EUW1 LAN LAS OCE RU TR JP] }
  validates :tier, inclusion: { in: %w[amateur semi_pro professional] }, allow_blank: true
  validates :subscription_plan, inclusion: { in: %w[free basic pro enterprise] }, allow_blank: true
  validates :subscription_status, inclusion: { in: %w[active inactive trial expired] }, allow_blank: true

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

    while Organization.exists?(slug: generated_slug)
      generated_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = generated_slug
  end
end