# frozen_string_literal: true

# Stores build configurations for champions, either created manually by coaches
# or automatically aggregated from match history by BuildAggregatorService.
#
# Multi-tenant: always scoped by organization_id.
# Performance metrics are calculated asynchronously by UpdateMetaStatsJob.
#
# @example Find best ADC builds for current patch
#   org.saved_builds.by_role('adc').by_patch('14.24').ranked_by_win_rate
class SavedBuild < ApplicationRecord
  belongs_to :organization
  belongs_to :created_by, class_name: 'User', optional: true

  DATA_SOURCES = %w[manual aggregated].freeze
  ROLES        = %w[top jungle mid adc support].freeze

  validates :champion,    presence: true, length: { maximum: 100 }
  validates :role,        inclusion: { in: ROLES }, allow_blank: true
  validates :data_source, inclusion: { in: DATA_SOURCES }
  validates :games_played, numericality: { greater_than_or_equal_to: 0 }
  validates :win_rate,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true

  # --- Scopes ---

  scope :by_champion, lambda { |champion|
    where(champion: champion)
  }

  scope :by_role, lambda { |role|
    where(role: role)
  }

  scope :by_patch, lambda { |patch|
    where(patch_version: patch)
  }

  scope :aggregated, -> { where(data_source: 'aggregated') }
  scope :manual,     -> { where(data_source: 'manual') }
  scope :public_builds, -> { where(is_public: true) }

  scope :ranked_by_win_rate, lambda {
    order(win_rate: :desc, games_played: :desc)
  }

  scope :with_sufficient_sample, lambda {
    where('games_played >= ?', BuildAggregatorService::MINIMUM_SAMPLE_SIZE)
  }

  # --- Predicates ---

  # @return [Boolean] true if this build was auto-generated from match data
  def aggregated?
    data_source == 'aggregated'
  end

  # @return [Boolean] true if this build was manually created by a coach
  def manual?
    data_source == 'manual'
  end

  # @return [String] win rate formatted for display (e.g. "62.5%")
  def win_rate_display
    "#{win_rate.to_f.round(1)}%"
  end
end
