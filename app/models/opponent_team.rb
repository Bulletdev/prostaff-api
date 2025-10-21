class OpponentTeam < ApplicationRecord
  # Concerns
  include Constants

  # Associations
  has_many :scrims, dependent: :nullify
  has_many :competitive_matches, dependent: :nullify

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :tag, length: { maximum: 10 }

  validates :region, inclusion: {
    in: Constants::REGIONS,
    message: "%{value} is not a valid region"
  }, allow_blank: true

  validates :tier, inclusion: {
    in: Constants::OpponentTeam::TIERS,
    message: "%{value} is not a valid tier"
  }, allow_blank: true

  # Callbacks
  before_save :normalize_name_and_tag

  # Scopes
  scope :by_region, ->(region) { where(region: region) }
  scope :by_tier, ->(tier) { where(tier: tier) }
  scope :by_league, ->(league) { where(league: league) }
  scope :professional, -> { where(tier: 'tier_1') }
  scope :semi_pro, -> { where(tier: 'tier_2') }
  scope :amateur, -> { where(tier: 'tier_3') }
  scope :with_scrims, -> { where('total_scrims > 0') }
  scope :ordered_by_scrim_count, -> { order(total_scrims: :desc) }

  # Instance methods
  def scrim_win_rate
    return 0 if total_scrims.zero?

    ((scrims_won.to_f / total_scrims) * 100).round(2)
  end

  def scrim_record
    "#{scrims_won}W - #{scrims_lost}L"
  end

  def update_scrim_stats!(victory:)
    self.total_scrims += 1

    if victory
      self.scrims_won += 1
    else
      self.scrims_lost += 1
    end

    save!
  end

  def tier_display
    case tier
    when 'tier_1'
      'Professional'
    when 'tier_2'
      'Semi-Pro'
    when 'tier_3'
      'Amateur'
    else
      'Unknown'
    end
  end

  # Returns full team name with tag if present
  # @return [String] Team name (e.g., "T1 (T1)" or just "T1")
  def full_name
    tag&.then { |t| "#{name} (#{t})" } || name
  end

  def contact_available?
    contact_email.present? || discord_server.present?
  end

  # Analytics methods

  # Returns the most preferred champion for a given role
  # @param role [String] The role (top, jungle, mid, adc, support)
  # @return [String, nil] Champion name or nil if not found
  def preferred_champion_by_role(role)
    preferred_champions&.dig(role)&.first
  end

  # Returns all strength tags for the team
  # @return [Array<String>] Array of strength tags
  def all_strengths_tags
    strengths || []
  end

  # Returns all weakness tags for the team
  # @return [Array<String>] Array of weakness tags
  def all_weaknesses_tags
    weaknesses || []
  end

  def add_strength(strength)
    return if strengths.include?(strength)

    self.strengths ||= []
    self.strengths << strength
    save
  end

  def add_weakness(weakness)
    return if weaknesses.include?(weakness)

    self.weaknesses ||= []
    self.weaknesses << weakness
    save
  end

  def remove_strength(strength)
    return unless strengths.include?(strength)

    self.strengths.delete(strength)
    save
  end

  def remove_weakness(weakness)
    return unless weaknesses.include?(weakness)

    self.weaknesses.delete(weakness)
    save
  end

  private

  def normalize_name_and_tag
    self.name = name.strip if name.present?
    self.tag = tag.strip.upcase if tag.present?
  end
end
