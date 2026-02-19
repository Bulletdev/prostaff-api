# frozen_string_literal: true

# Represents a League of Legends match/game
#
# Matches store game data including results, statistics, and metadata.
# They can be official competitive matches, scrims, or tournament games.
# Match data can be imported from Riot API or created manually.
#
# @attr [String] match_type Type of match: official, scrim, or tournament
# @attr [DateTime] game_start When the match started
# @attr [DateTime] game_end When the match ended
# @attr [Integer] game_duration Duration in seconds
# @attr [String] riot_match_id Riot's unique match identifier
# @attr [String] patch_version Game patch version (e.g., "13.24")
# @attr [String] opponent_name Name of the opposing team
# @attr [Boolean] victory Whether the organization won the match
# @attr [String] our_side Which side the team played on: blue or red
# @attr [Integer] our_score Team's score (kills or games won in series)
# @attr [Integer] opponent_score Opponent's score
# @attr [String] vod_url Link to video recording of the match
#
# @example Creating a match
#   match = Match.create!(
#     organization: org,
#     match_type: "scrim",
#     game_start: Time.current,
#     victory: true
#   )
#
# @example Finding recent victories
#   recent_wins = Match.victories.recent(7)
#
class Match < ApplicationRecord
  # Concerns
  include Constants
  include OrganizationScoped

  # Associations
  belongs_to :organization
  has_many :player_match_stats, dependent: :destroy
  has_many :players, through: :player_match_stats
  has_many :schedules, dependent: :nullify
  has_many :vod_reviews, dependent: :destroy

  # Validations
  validates :match_type, presence: true, inclusion: { in: Constants::Match::TYPES }
  validates :riot_match_id, uniqueness: true, allow_blank: true
  validates :our_side, inclusion: { in: Constants::Match::SIDES }, allow_blank: true
  validates :game_duration, numericality: { greater_than: 0 }, allow_blank: true

  # Callbacks
  after_update :log_audit_trail, if: :saved_changes?
  after_create :clear_organization_cache
  after_destroy :clear_organization_cache

  # Scopes
  scope :by_type, ->(type) { where(match_type: type) }
  scope :victories, -> { where(victory: true) }
  scope :defeats, -> { where(victory: false) }
  scope :recent, ->(days = 30) { where(game_start: days.days.ago..Time.current) }
  scope :in_date_range, ->(start_date, end_date) { where(game_start: start_date..end_date) }
  scope :with_opponent, ->(opponent) { where('opponent_name ILIKE ?', "%#{opponent}%") }

  # Instance methods
  def result_text
    return 'Unknown' if victory.nil?

    victory? ? 'Victory' : 'Defeat'
  end

  def duration_formatted
    return 'Unknown' if game_duration.blank?

    minutes = game_duration / 60
    seconds = game_duration % 60
    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end

  def score_display
    return 'Unknown' if our_score.blank? || opponent_score.blank?

    "#{our_score} - #{opponent_score}"
  end

  def kda_summary
    # Single aggregate query instead of 3 separate SUM calls
    row = player_match_stats
      .select('SUM(kills) AS k, SUM(deaths) AS d, SUM(assists) AS a')
      .take

    total_kills   = row&.k.to_i
    total_deaths  = row&.d.to_i
    total_assists = row&.a.to_i
    deaths_divisor = total_deaths.zero? ? 1 : total_deaths

    {
      kills:   total_kills,
      deaths:  total_deaths,
      assists: total_assists,
      kda:     ((total_kills + total_assists).to_f / deaths_divisor).round(2)
    }
  end

  def gold_advantage
    return nil if our_score.blank? || opponent_score.blank?

    our_gold = player_match_stats.sum(:gold_earned)
    # Assuming opponent gold is estimated based on game duration and average values
    estimated_opponent_gold = game_duration.present? ? game_duration * 350 * 5 : nil

    return nil if estimated_opponent_gold.blank?

    our_gold - estimated_opponent_gold
  end

  def mvp_player
    return nil if player_match_stats.empty?

    player_match_stats
      .joins(:player)
      .order(performance_score: :desc, kills: :desc, assists: :desc)
      .first&.player
  end

  def team_composition
    player_match_stats.includes(:player).map do |stat|
      {
        player: stat.player.summoner_name,
        champion: stat.champion,
        role: stat.role
      }
    end
  end

  def has_replay?
    replay_file_url.present?
  end

  def has_vod?
    vod_url.present?
  end

  private

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      action: 'update',
      entity_type: 'Match',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end

  def clear_organization_cache
    organization.clear_matches_cache if organization.present?
  end
end
