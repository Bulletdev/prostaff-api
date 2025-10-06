class VodTimestamp < ApplicationRecord
  # Associations
  belongs_to :vod_review
  belongs_to :target_player, class_name: 'Player', optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  # Validations
  validates :timestamp_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :title, presence: true, length: { maximum: 255 }
  validates :category, inclusion: { in: %w[mistake good_play team_fight objective laning] }, allow_blank: true
  validates :importance, inclusion: { in: %w[low normal high critical] }
  validates :target_type, inclusion: { in: %w[player team opponent] }, allow_blank: true

  # Scopes
  scope :by_category, ->(category) { where(category: category) }
  scope :by_importance, ->(importance) { where(importance: importance) }
  scope :by_target_type, ->(type) { where(target_type: type) }
  scope :important, -> { where(importance: %w[high critical]) }
  scope :chronological, -> { order(:timestamp_seconds) }
  scope :for_player, ->(player_id) { where(target_player_id: player_id) }

  # Instance methods
  def timestamp_formatted
    hours = timestamp_seconds / 3600
    minutes = (timestamp_seconds % 3600) / 60
    seconds = timestamp_seconds % 60

    if hours > 0
      "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
    else
      "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
    end
  end

  def importance_color
    case importance
    when 'low' then 'gray'
    when 'normal' then 'blue'
    when 'high' then 'orange'
    when 'critical' then 'red'
    else 'gray'
    end
  end

  def category_color
    case category
    when 'mistake' then 'red'
    when 'good_play' then 'green'
    when 'team_fight' then 'purple'
    when 'objective' then 'blue'
    when 'laning' then 'yellow'
    else 'gray'
    end
  end

  def category_icon
    case category
    when 'mistake' then '⚠️'
    when 'good_play' then '✅'
    when 'team_fight' then '⚔️'
    when 'objective' then '🎯'
    when 'laning' then '🛡️'
    else '📝'
    end
  end

  def target_display
    case target_type
    when 'player'
      target_player&.summoner_name || 'Unknown Player'
    when 'team'
      'Team'
    when 'opponent'
      'Opponent'
    else
      'General'
    end
  end

  def video_url_with_timestamp
    base_url = vod_review.video_url
    return base_url unless base_url.present?

    # Handle YouTube URLs
    if base_url.include?('youtube.com') || base_url.include?('youtu.be')
      separator = base_url.include?('?') ? '&' : '?'
      "#{base_url}#{separator}t=#{timestamp_seconds}s"
    # Handle Twitch URLs
    elsif base_url.include?('twitch.tv')
      separator = base_url.include?('?') ? '&' : '?'
      "#{base_url}#{separator}t=#{timestamp_seconds}s"
    else
      # For other video platforms, just return the base URL
      base_url
    end
  end

  def is_important?
    %w[high critical].include?(importance)
  end

  def is_mistake?
    category == 'mistake'
  end

  def is_highlight?
    category == 'good_play'
  end

  def organization
    vod_review.organization
  end

  def can_be_edited_by?(user)
    created_by == user || user.admin_or_owner?
  end

  def next_timestamp
    vod_review.vod_timestamps
      .where('timestamp_seconds > ?', timestamp_seconds)
      .order(:timestamp_seconds)
      .first
  end

  def previous_timestamp
    vod_review.vod_timestamps
      .where('timestamp_seconds < ?', timestamp_seconds)
      .order(:timestamp_seconds)
      .last
  end
end