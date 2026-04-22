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
  def self.uptime_by_day(component:, days: 90)
    rows    = for_component(component).recent(days).order(checked_at: :asc).pluck(:checked_at, :status)
    rows.group_by { |checked_at, _| checked_at.to_date }
        .map { |date, entries| aggregate_day(date, entries) }
  end

  # Single-query bulk version: returns { component => [{ date:, uptime_pct:, status: }] }
  def self.bulk_uptime_by_day(days: 90)
    rows = where(checked_at: days.days.ago..Time.current)
             .order(checked_at: :asc)
             .pluck(:component, :checked_at, :status)

    rows
      .group_by(&:first)
      .transform_values do |component_rows|
        component_rows
          .map { |_, checked_at, status| [checked_at, status] }
          .group_by { |checked_at, _| checked_at.to_date }
          .map { |date, entries| aggregate_day(date, entries) }
      end
  end

  # Single-query bulk version: returns { component => snapshot } for the latest per component
  def self.latest_per_component
    select('DISTINCT ON (component) *')
      .order('component, checked_at DESC')
      .index_by(&:component)
  end

  def self.aggregate_day(date, entries)
    total      = entries.size
    ok         = entries.count { |_, s| s == 'operational' }
    uptime_pct = (ok.to_f / total * 100).round(2)
    dominant   = entries.map { |_, s| s }.tally.max_by { |_, c| c }&.first
    { date: date, uptime_pct: uptime_pct, status: dominant }
  end
  private_class_method :aggregate_day
end
