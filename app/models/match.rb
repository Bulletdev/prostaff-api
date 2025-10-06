class Match < ApplicationRecord
  # Associations
  belongs_to :organization
  has_many :player_match_stats, dependent: :destroy
  has_many :players, through: :player_match_stats
  has_many :schedules, dependent: :nullify
  has_many :vod_reviews, dependent: :destroy

  # Validations
  validates :match_type, presence: true, inclusion: { in: %w[official scrim tournament] }
  validates :riot_match_id, uniqueness: true, allow_blank: true
  validates :our_side, inclusion: { in: %w[blue red] }, allow_blank: true
  validates :game_duration, numericality: { greater_than: 0 }, allow_blank: true

  # Callbacks
  after_update :log_audit_trail, if: :saved_changes?

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
    stats = player_match_stats.includes(:player)
    total_kills = stats.sum(:kills)
    total_deaths = stats.sum(:deaths)
    total_assists = stats.sum(:assists)

    deaths = total_deaths.zero? ? 1 : total_deaths
    kda = (total_kills + total_assists).to_f / deaths

    {
      kills: total_kills,
      deaths: total_deaths,
      assists: total_assists,
      kda: kda.round(2)
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
end