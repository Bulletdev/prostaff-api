class Player < ApplicationRecord
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
  validates :role, presence: true, inclusion: { in: %w[top jungle mid adc support] }
  validates :country, length: { maximum: 2 }
  validates :status, inclusion: { in: %w[active inactive benched trial] }
  validates :riot_puuid, uniqueness: true, allow_blank: true
  validates :riot_summoner_id, uniqueness: true, allow_blank: true
  validates :jersey_number, uniqueness: { scope: :organization_id }, allow_blank: true
  validates :solo_queue_tier, inclusion: {
    in: %w[IRON BRONZE SILVER GOLD PLATINUM EMERALD DIAMOND MASTER GRANDMASTER CHALLENGER]
  }, allow_blank: true
  validates :solo_queue_rank, inclusion: { in: %w[I II III IV] }, allow_blank: true
  validates :flex_queue_tier, inclusion: {
    in: %w[IRON BRONZE SILVER GOLD PLATINUM EMERALD DIAMOND MASTER GRANDMASTER CHALLENGER]
  }, allow_blank: true
  validates :flex_queue_rank, inclusion: { in: %w[I II III IV] }, allow_blank: true

  # Callbacks
  before_save :normalize_summoner_name
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :by_status, ->(status) { where(status: status) }
  scope :active, -> { where(status: 'active') }
  scope :with_contracts, -> { where.not(contract_start_date: nil) }
  scope :contracts_expiring_soon, ->(days = 30) {
    where(contract_end_date: Date.current..Date.current + days.days)
  }
  scope :by_tier, ->(tier) { where(solo_queue_tier: tier) }

  # Instance methods
  def current_rank_display
    return 'Unranked' if solo_queue_tier.blank?

    rank_part = solo_queue_rank.present? ? " #{solo_queue_rank}" : ""
    lp_part = solo_queue_lp.present? ? " (#{solo_queue_lp} LP)" : ""

    "#{solo_queue_tier.titleize}#{rank_part}#{lp_part}"
  end

  def peak_rank_display
    return 'No peak recorded' if peak_tier.blank?

    rank_part = peak_rank.present? ? " #{peak_rank}" : ""
    season_part = peak_season.present? ? " (S#{peak_season})" : ""

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
    return 0 if solo_queue_wins.to_i + solo_queue_losses.to_i == 0

    total_games = solo_queue_wins.to_i + solo_queue_losses.to_i
    (solo_queue_wins.to_f / total_games * 100).round(1)
  end

  def main_champions
    champion_pools.order(games_played: :desc, average_kda: :desc).limit(3).pluck(:champion)
  end

  def needs_sync?
    last_sync_at.blank? || last_sync_at < 1.hour.ago
  end

  def social_links
    links = {}
    links[:twitter] = "https://twitter.com/#{twitter_handle}" if twitter_handle.present?
    links[:twitch] = "https://twitch.tv/#{twitch_channel}" if twitch_channel.present?
    links[:instagram] = "https://instagram.com/#{instagram_handle}" if instagram_handle.present?
    links
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