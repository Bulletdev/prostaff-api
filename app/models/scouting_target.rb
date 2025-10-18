class ScoutingTarget < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :added_by, class_name: 'User', optional: true
  belongs_to :assigned_to, class_name: 'User', optional: true

  # Validations
  validates :summoner_name, presence: true, length: { maximum: 100 }
  validates :region, presence: true, inclusion: { in: %w[BR NA EUW KR EUNE LAN LAS OCE RU TR JP] }
  validates :role, presence: true, inclusion: { in: %w[top jungle mid adc support] }
  validates :status, inclusion: { in: %w[watching contacted negotiating rejected signed] }
  validates :priority, inclusion: { in: %w[low medium high critical] }
  validates :riot_puuid, uniqueness: true, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Callbacks
  before_save :normalize_summoner_name
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_role, ->(role) { where(role: role) }
  scope :by_region, ->(region) { where(region: region) }
  scope :active, -> { where(status: %w[watching contacted negotiating]) }
  scope :high_priority, -> { where(priority: %w[high critical]) }
  scope :needs_review, -> { where('last_reviewed IS NULL OR last_reviewed < ?', 1.week.ago) }
  scope :assigned_to_user, ->(user_id) { where(assigned_to_id: user_id) }

  # Instance methods
  # Returns formatted display of current ranked status
  # @return [String] Formatted rank (e.g., "Diamond II (75 LP)" or "Unranked")
  def current_rank_display
    return 'Unranked' if current_tier.blank?

    rank_part = current_rank&.then { |r| " #{r}" } || ""
    lp_part = current_lp&.then { |lp| " (#{lp} LP)" } || ""

    "#{current_tier.titleize}#{rank_part}#{lp_part}"
  end

  def status_color
    case status
    when 'watching' then 'blue'
    when 'contacted' then 'yellow'
    when 'negotiating' then 'orange'
    when 'rejected' then 'red'
    when 'signed' then 'green'
    else 'gray'
    end
  end

  def priority_color
    case priority
    when 'low' then 'gray'
    when 'medium' then 'blue'
    when 'high' then 'orange'
    when 'critical' then 'red'
    else 'gray'
    end
  end

  def priority_score
    case priority
    when 'low' then 1
    when 'medium' then 2
    when 'high' then 3
    when 'critical' then 4
    else 0
    end
  end

  def performance_trend_color
    case performance_trend
    when 'improving' then 'green'
    when 'stable' then 'blue'
    when 'declining' then 'red'
    else 'gray'
    end
  end

  def needs_review?
    last_reviewed.blank? || last_reviewed < 1.week.ago
  end

  def days_since_review
    return 'Never' if last_reviewed.blank?

    days = (Date.current - last_reviewed.to_date).to_i
    case days
    when 0 then 'Today'
    when 1 then 'Yesterday'
    else "#{days} days ago"
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

  def mark_as_reviewed!(user = nil)
    update!(
      last_reviewed: Time.current,
      assigned_to: user || assigned_to
    )
  end

  def advance_status!
    new_status = case status
                 when 'watching' then 'contacted'
                 when 'contacted' then 'negotiating'
                 when 'negotiating' then 'signed'
                 else status
                 end

    update!(status: new_status, last_reviewed: Time.current)
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

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      action: 'update',
      entity_type: 'ScoutingTarget',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end
end