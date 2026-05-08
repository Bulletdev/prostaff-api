# frozen_string_literal: true

# Represents a recurring time slot when an organization is available for scrims.
class AvailabilityWindow < ApplicationRecord
  include OrganizationScoped

  DAYS_OF_WEEK = %w[sunday monday tuesday wednesday thursday friday saturday].freeze
  TIER_PREFERENCES = %w[any same adjacent].freeze
  GAMES = %w[league_of_legends valorant cs2 dota2].freeze
  REGIONS = %w[BR NA EUW EUNE LAN LAS OCE KR JP TR RU].freeze

  belongs_to :organization

  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :start_hour, presence: true, inclusion: { in: 0..23 }
  validates :end_hour, presence: true, inclusion: { in: 0..23 }
  validates :game, presence: true, inclusion: { in: GAMES }
  validates :tier_preference, inclusion: { in: TIER_PREFERENCES }
  validates :region, inclusion: { in: REGIONS }, allow_blank: true
  validate :end_hour_after_start_hour

  scope :active, -> { where(active: true).where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :by_game, ->(game) { where(game: game) }
  scope :by_region, ->(region) { where(region: region) }
  scope :by_day, ->(day) { where(day_of_week: day) }
  scope :available_now, lambda {
    current_day = Time.current.wday
    current_hour = Time.current.hour
    active.where(day_of_week: current_day)
          .where('start_hour <= ? AND end_hour > ?', current_hour, current_hour)
  }

  def day_name
    DAYS_OF_WEEK[day_of_week]
  end

  def time_range_display
    "#{start_hour.to_s.rjust(2, '0')}:00 - #{end_hour.to_s.rjust(2, '0')}:00 #{timezone}"
  end

  def duration_hours
    end_hour - start_hour
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  private

  def end_hour_after_start_hour
    return unless start_hour.present? && end_hour.present?

    errors.add(:end_hour, 'must be after start hour') if end_hour <= start_hour
  end
end
