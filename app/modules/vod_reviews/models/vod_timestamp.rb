# frozen_string_literal: true

# A timestamped annotation within a VOD review, categorized by type and importance.
class VodTimestamp < ApplicationRecord
  # Concerns
  include Constants

  # Associations
  belongs_to :vod_review
  belongs_to :target_player, class_name: 'Player', optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  # Validations
  validates :timestamp_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :title, presence: true, length: { maximum: 255 }
  validates :category, inclusion: { in: Constants::VodTimestamp::CATEGORIES }, allow_blank: true
  validates :importance, inclusion: { in: Constants::VodTimestamp::IMPORTANCE_LEVELS }
  validates :target_type, inclusion: { in: Constants::VodTimestamp::TARGET_TYPES }, allow_blank: true
  validate :timestamp_within_duration
  validate :drawing_data_size

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

    if hours.positive?
      "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
    else
      "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
    end
  end

  def importance_color
    return 'blue' if importance == 'normal'
    return 'orange' if importance == 'high'
    return 'red' if importance == 'critical'

    'gray'
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

    # Handle YouTube and Twitch URLs (both use same timestamp format)
    if base_url.include?('youtube.com') || base_url.include?('youtu.be') || base_url.include?('twitch.tv')
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

  private

  # Validates that drawing_data does not exceed the 500KB size limit.
  def drawing_data_size
    return unless drawing_data.present?

    serialized = drawing_data.to_json
    return unless serialized.bytesize > 500.kilobytes

    errors.add(:drawing_data, 'exceeds maximum size of 500KB')
  end

  # Validates that the timestamp does not exceed the video duration.
  # Only enforced when the associated review has a known duration.
  def timestamp_within_duration
    return unless vod_review&.duration.present?
    return unless timestamp_seconds.present?
    return unless timestamp_seconds > vod_review.duration

    errors.add(:timestamp_seconds, 'exceeds video duration')
  end
end
