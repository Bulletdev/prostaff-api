# frozen_string_literal: true

# Point-in-time health record for a single infrastructure component.
# Written every 5 minutes by StatusSnapshotJob and used to calculate
# uptime percentages on the public status page.
class StatusSnapshot < ApplicationRecord
  COMPONENTS = StatusIncident::COMPONENTS
  STATUSES   = %w[operational degraded_performance partial_outage major_outage].freeze

  validates :component,  inclusion: { in: COMPONENTS }
  validates :status,     inclusion: { in: STATUSES }
  validates :checked_at, presence: true

  scope :recent,        ->(days = 90) { where(checked_at: days.days.ago..Time.current) }
  scope :for_component, ->(component) { where(component: component) }

  # Returns daily uptime percentage for a component over the last N days.
  #
  # @param component [String] one of COMPONENTS
  # @param days [Integer] number of days to look back (default 90)
  # @return [Array<Hash>] array of { date: Date, uptime_pct: Float, status: String }
  #   Days without snapshots are omitted from the result.
  def self.uptime_by_day(component:, days: 90)
    rows    = fetch_rows(component, days)
    grouped = rows.group_by { |checked_at, _| checked_at.to_date }
    grouped.map { |date, entries| aggregate_day(date, entries) }
  end

  private_class_method def self.fetch_rows(component, days)
    for_component(component)
      .recent(days)
      .order(checked_at: :asc)
      .pluck(:checked_at, :status)
  end

  private_class_method def self.aggregate_day(date, entries)
    total      = entries.size
    ok         = entries.count { |_, s| s == 'operational' }
    uptime_pct = (ok.to_f / total * 100).round(2)
    dominant   = entries.map { |_, s| s }.tally.max_by { |_, c| c }&.first
    { date: date, uptime_pct: uptime_pct, status: dominant }
  end
end
