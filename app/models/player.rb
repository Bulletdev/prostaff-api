# frozen_string_literal: true

# Represents a player (athlete) in a League of Legends organization
#
# Players are the core entities in the roster management system. Each player
# belongs to an organization and has associated match statistics, champion pools,
# and rank information synced from the Riot Games API.
#
# @attr [String] summoner_name The player's in-game summoner name (required)
# @attr [String] real_name The player's real legal name (optional)
# @attr [String] role The player's primary position: top, jungle, mid, adc, or support
# @attr [String] status Player's roster status: active, inactive, benched, or trial
# @attr [String] riot_puuid Riot's universal unique identifier for the player
# @attr [String] riot_summoner_id Riot's summoner ID for API calls
# @attr [Integer] jersey_number Player's team jersey number (unique per organization)
# @attr [String] solo_queue_tier Current ranked tier (IRON to CHALLENGER)
# @attr [String] solo_queue_rank Current ranked division (I to IV)
# @attr [Integer] solo_queue_lp Current League Points in ranked
# @attr [Date] contract_start_date Contract start date
# @attr [Date] contract_end_date Contract end date
#
# @example Creating a new player
#   player = Player.create!(
#     summoner_name: "Faker",
#     role: "mid",
#     organization: org,
#     status: "active"
#   )
#
# @example Finding active players by role
#   mid_laners = Player.active.by_role("mid")
#
class Player < ApplicationRecord
  # Concerns
  include Constants

  # Associations
  belongs_to :organization
  has_many :player_match_stats, dependent: :destroy
  has_many :matches, through: :player_match_stats
  has_many :champion_pools, dependent: :destroy
  has_many :team_goals, dependent: :destroy
  has_many :vod_timestamps, foreign_key: 'target_player_id', dependent: :nullify

  # Validations
  validates :summoner_name, presence: true, length: { maximum: 100 }
  validates :real_name, length: { maximum: 255 }
  validates :role, presence: true, inclusion: { in: Constants::Player::ROLES }
  validates :country, length: { maximum: 2 }
  validates :status, inclusion: { in: Constants::Player::STATUSES }
  validates :riot_puuid, uniqueness: true, allow_blank: true
  validates :riot_summoner_id, uniqueness: true, allow_blank: true
  validates :jersey_number, uniqueness: { scope: :organization_id }, allow_blank: true
  validates :solo_queue_tier, inclusion: { in: Constants::Player::QUEUE_TIERS }, allow_blank: true
  validates :solo_queue_rank, inclusion: { in: Constants::Player::QUEUE_RANKS }, allow_blank: true
  validates :flex_queue_tier, inclusion: { in: Constants::Player::QUEUE_TIERS }, allow_blank: true
  validates :flex_queue_rank, inclusion: { in: Constants::Player::QUEUE_RANKS }, allow_blank: true

  # Callbacks
  before_save :normalize_summoner_name
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :by_status, ->(status) { where(status: status) }
  scope :active, -> { where(status: 'active') }
  scope :with_contracts, -> { where.not(contract_start_date: nil) }
  scope :contracts_expiring_soon, lambda { |days = 30|
    where(contract_end_date: Date.current..Date.current + days.days)
  }
  scope :by_tier, ->(tier) { where(solo_queue_tier: tier) }
  scope :ordered_by_role, lambda {
    order(Arel.sql(
            "CASE role
        WHEN 'top' THEN 1
        WHEN 'jungle' THEN 2
        WHEN 'mid' THEN 3
        WHEN 'adc' THEN 4
        WHEN 'support' THEN 5
        ELSE 6
      END"
          ))
  }

  # Instance methods
  # Returns formatted display of current ranked status
  # @return [String] Formatted rank (e.g., "Diamond II (75 LP)" or "Unranked")
  def current_rank_display
    return 'Unranked' if solo_queue_tier.blank?

    rank_part = solo_queue_rank&.then { |r| " #{r}" } || ''
    lp_part = solo_queue_lp&.then { |lp| " (#{lp} LP)" } || ''

    "#{solo_queue_tier.titleize}#{rank_part}#{lp_part}"
  end

  # Returns formatted display of peak rank achieved
  # @return [String] Formatted peak rank (e.g., "Master I (S13)" or "No peak recorded")
  def peak_rank_display
    return 'No peak recorded' if peak_tier.blank?

    rank_part = peak_rank&.then { |r| " #{r}" } || ''
    season_part = peak_season&.then { |s| " (S#{s})" } || ''

    "#{peak_tier.titleize}#{rank_part}#{season_part}"
  end

  def contract_status
    return 'No contract' if contract_start_date.blank? || contract_end_date.blank?

    if contract_end_date < Date.current
      'Expired'
    elsif contract_end_date <= Date.current + 30.days
      'Expiring soon'
    else
      'Active'
    end
  end

  def age
    return nil if birth_date.blank?

    ((Date.current - birth_date) / 365.25).floor
  end

  def win_rate
    return 0 if (solo_queue_wins.to_i + solo_queue_losses.to_i).zero?

    total_games = solo_queue_wins.to_i + solo_queue_losses.to_i
    (solo_queue_wins.to_f / total_games * 100).round(1)
  end

  def main_champions
    champion_pools.order(games_played: :desc, average_kda: :desc).limit(3).pluck(:champion)
  end

  def needs_sync?
    last_sync_at.blank? || last_sync_at < 1.hour.ago
  end

  # Returns hash of social media links for the player
  # @return [Hash] Social media URLs (only includes present handles)
  def social_links
    {
      twitter: twitter_handle&.then { |h| "https://twitter.com/#{h}" },
      twitch: twitch_channel&.then { |c| "https://twitch.tv/#{c}" },
      instagram: instagram_handle&.then { |h| "https://instagram.com/#{h}" }
    }.compact
  end

  private

  def normalize_summoner_name
    self.summoner_name = summoner_name.strip if summoner_name.present?
  end

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      action: 'update',
      entity_type: 'Player',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end
end
