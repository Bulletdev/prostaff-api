# frozen_string_literal: true

# ScoutingTarget represents a global player available for scouting
#
# This is the GLOBAL layer - no organization_id.
# All organizations can see all scouting targets (free agents).
# Organization-specific tracking is done through ScoutingWatchlist.
#
# @attr [String] summoner_name Player's in-game name
# @attr [String] region Server region (BR, NA, KR, etc.)
# @attr [String] riot_puuid Riot's unique player identifier (globally unique)
# @attr [String] role Position (top, jungle, mid, adc, support)
# @attr [String] status Player status (free_agent, watching, etc.)
# @attr [String] current_tier Current ranked tier
# @attr [String] current_rank Current rank within tier
# @attr [Integer] current_lp Current LP
# @attr [Array] champion_pool Champions the player is known for
# @attr [JSONB] recent_performance Recent performance metrics
class ScoutingTarget < ApplicationRecord
  # Concerns
  # REMOVED: include OrganizationScoped (this is now global)
  include Constants

  # Associations
  # REMOVED: belongs_to :organization
  # REMOVED: belongs_to :added_by
  # REMOVED: belongs_to :assigned_to

  # NEW: Many-to-many with organizations through watchlists
  has_many :scouting_watchlists, dependent: :destroy
  has_many :organizations, through: :scouting_watchlists

  # Validations
  validates :summoner_name, presence: true, length: { maximum: 100 }
  validates :region, presence: true, inclusion: { in: Constants::REGIONS }
  validates :role, presence: true, inclusion: { in: Constants::Player::ROLES }
  validates :status, inclusion: { in: Constants::ScoutingTarget::STATUSES }
  validates :riot_puuid, uniqueness: true, allow_blank: true # Global uniqueness
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Callbacks
  before_save :normalize_summoner_name

  # Scopes - GLOBAL scopes (no org filtering)
  scope :by_status, ->(status) { where(status: status) }
  scope :by_role, ->(role) { where(role: role) }
  scope :by_region, ->(region) { where(region: region) }
  scope :free_agents, -> { where(status: 'free_agent') }

  # Instance methods
  # Returns formatted display of current ranked status
  # @return [String] Formatted rank (e.g., "Diamond II (75 LP)" or "Unranked")
  def current_rank_display
    return 'Unranked' if current_tier.blank?

    rank_part = current_rank&.then { |r| " #{r}" } || ''
    lp_part = current_lp&.then { |lp| " (#{lp} LP)" } || ''

    "#{current_tier.titleize}#{rank_part}#{lp_part}"
  end

  def performance_trend_color
    case performance_trend
    when 'improving' then 'green'
    when 'stable' then 'blue'
    when 'declining' then 'red'
    else 'gray'
    end
  end

  # Returns hash of contact information for the target
  # @return [Hash] Contact details (only includes present values)
  def contact_info
    {
      email: email,
      phone: phone,
      discord: discord_username,
      twitter: twitter_handle&.then { |h| "https://twitter.com/#{h}" }
    }.compact
  end

  def main_champions
    champion_pool.first(3)
  end

  def estimated_salary_range
    # This would be based on tier, region, and performance
    case current_tier&.upcase
    when 'CHALLENGER', 'GRANDMASTER'
      case region.upcase
      when 'BR' then '$3,000 - $8,000'
      when 'NA', 'EUW' then '$5,000 - $15,000'
      when 'KR' then '$8,000 - $20,000'
      else '$2,000 - $6,000'
      end
    when 'MASTER'
      case region.upcase
      when 'BR' then '$1,500 - $4,000'
      when 'NA', 'EUW' then '$2,500 - $8,000'
      when 'KR' then '$4,000 - $12,000'
      else '$1,000 - $3,000'
      end
    else
      '$500 - $2,000'
    end
  end

  # Calculates overall scouting score (0-130)
  #
  # @return [Integer] Scouting score based on rank, trend, and champion pool
  def scouting_score
    total = rank_score + trend_score + pool_diversity_score
    [total, 0].max
  end

  # Check if this target is in a specific organization's watchlist
  # @param organization [Organization] The organization to check
  # @return [ScoutingWatchlist, nil] The watchlist entry if exists
  def watchlist_for(organization)
    scouting_watchlists.find_by(organization: organization)
  end

  # Check if this target is being watched by a specific organization
  # @param organization [Organization] The organization to check
  # @return [Boolean]
  def watched_by?(organization)
    watchlist_for(organization).present?
  end

  private

  # Scores based on current rank (10-100 points)
  def rank_score
    case current_tier&.upcase
    when 'CHALLENGER' then 100
    when 'GRANDMASTER' then 90
    when 'MASTER' then 80
    when 'DIAMOND' then 60
    when 'EMERALD' then 40
    when 'PLATINUM' then 25
    else 10
    end
  end

  # Scores based on performance trend (-10 to 20 points)
  def trend_score
    case performance_trend
    when 'improving' then 20
    when 'stable' then 10
    when 'declining' then -10
    else 0
    end
  end

  # Scores based on champion pool diversity (-10 to 10 points)
  def pool_diversity_score
    case champion_pool.size
    when 0..2 then -10
    when 3..5 then 0
    when 6..8 then 10
    else 5
    end
  end

  def normalize_summoner_name
    self.summoner_name = summoner_name.strip if summoner_name.present?
  end
end
