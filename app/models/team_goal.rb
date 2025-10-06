class TeamGoal < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :player, optional: true
  belongs_to :assigned_to, class_name: 'User', optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :category, inclusion: { in: %w[performance rank tournament skill] }, allow_blank: true
  validates :metric_type, inclusion: { in: %w[win_rate kda cs_per_min vision_score damage_share rank_climb] }, allow_blank: true
  validates :start_date, :end_date, presence: true
  validates :status, inclusion: { in: %w[active completed failed cancelled] }
  validates :progress, numericality: { in: 0..100 }
  validate :end_date_after_start_date

  # Callbacks
  before_save :calculate_progress_if_needed
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_category, ->(category) { where(category: category) }
  scope :active, -> { where(status: 'active') }
  scope :team_goals, -> { where(player_id: nil) }
  scope :player_goals, -> { where.not(player_id: nil) }
  scope :for_player, ->(player_id) { where(player_id: player_id) }
  scope :expiring_soon, ->(days = 7) { where(end_date: Date.current..Date.current + days.days) }
  scope :overdue, -> { where('end_date < ? AND status = ?', Date.current, 'active') }

  # Instance methods
  def is_team_goal?
    player_id.nil?
  end

  def is_player_goal?
    player_id.present?
  end

  def days_remaining
    return 0 if end_date < Date.current

    (end_date - Date.current).to_i
  end

  def days_total
    (end_date - start_date).to_i
  end

  def days_elapsed
    return days_total if Date.current > end_date

    [(Date.current - start_date).to_i, 0].max
  end

  def time_progress_percentage
    return 100 if Date.current >= end_date

    (days_elapsed.to_f / days_total * 100).round(1)
  end

  def is_overdue?
    Date.current > end_date && status == 'active'
  end

  def is_expiring_soon?(days = 7)
    days_remaining <= days && status == 'active'
  end

  def status_color
    case status
    when 'active' then is_overdue? ? 'red' : 'blue'
    when 'completed' then 'green'
    when 'failed' then 'red'
    when 'cancelled' then 'gray'
    else 'gray'
    end
  end

  def progress_color
    case progress
    when 0...25 then 'red'
    when 25...50 then 'orange'
    when 50...75 then 'yellow'
    when 75...90 then 'blue'
    when 90..100 then 'green'
    else 'gray'
    end
  end

  def target_display
    return 'N/A' if target_value.blank?

    case metric_type
    when 'win_rate' then "#{target_value}%"
    when 'kda' then target_value.to_s
    when 'cs_per_min' then "#{target_value} CS/min"
    when 'vision_score' then "#{target_value} Vision Score"
    when 'damage_share' then "#{target_value}% Damage Share"
    when 'rank_climb' then rank_display(target_value.to_i)
    else target_value.to_s
    end
  end

  def current_display
    return 'N/A' if current_value.blank?

    case metric_type
    when 'win_rate' then "#{current_value}%"
    when 'kda' then current_value.to_s
    when 'cs_per_min' then "#{current_value} CS/min"
    when 'vision_score' then "#{current_value} Vision Score"
    when 'damage_share' then "#{current_value}% Damage Share"
    when 'rank_climb' then rank_display(current_value.to_i)
    else current_value.to_s
    end
  end

  def completion_percentage
    return 0 if target_value.blank? || current_value.blank? || target_value.zero?

    [(current_value / target_value * 100).round(1), 100].min
  end

  def mark_as_completed!
    update!(
      status: 'completed',
      progress: 100,
      current_value: target_value
    )
  end

  def mark_as_failed!
    update!(status: 'failed')
  end

  def mark_as_cancelled!
    update!(status: 'cancelled')
  end

  def update_progress!(new_current_value)
    self.current_value = new_current_value
    calculate_progress_if_needed
    save!
  end

  def assigned_to_name
    assigned_to&.full_name || assigned_to&.email&.split('@')&.first || 'Unassigned'
  end

  def player_name
    player&.summoner_name || 'Team Goal'
  end

  def self.metrics_for_role(role)
    case role
    when 'adc', 'mid'
      %w[win_rate kda cs_per_min damage_share]
    when 'support'
      %w[win_rate kda vision_score]
    when 'jungle'
      %w[win_rate kda vision_score damage_share]
    when 'top'
      %w[win_rate kda cs_per_min]
    else
      %w[win_rate kda]
    end
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, 'must be after start date') if end_date <= start_date
  end

  def calculate_progress_if_needed
    return unless target_value.present? && current_value.present?

    self.progress = completion_percentage.round
  end

  def rank_display(tier_number)
    tiers = %w[Iron Bronze Silver Gold Platinum Emerald Diamond Master Grandmaster Challenger]
    tiers[tier_number] || 'Unknown'
  end

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      action: 'update',
      entity_type: 'TeamGoal',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end
end