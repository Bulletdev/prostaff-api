# frozen_string_literal: true

# Global Contract Database record from Leaguepedia GCD.
# Public data — no organization_id (unlike Contract which is private/confidential).
# contract_end_date is indicative only — often empty or stale in source data.
class MarketRegistration < ApplicationRecord
  SOURCES = %w[leaguepedia_gcd].freeze

  belongs_to :scouting_target, optional: true

  validates :player_external_name, presence: true
  validates :snapshot_date, presence: true
  validates :source, inclusion: { in: SOURCES }

  scope :for_region, lambda { |region|
    where(region: region) if region.present?
  }
  scope :search_query, lambda { |q|
    where('player_external_name ILIKE ? OR team_name ILIKE ?', "%#{q}%", "%#{q}%") if q.present?
  }
  scope :expiring_before, lambda { |date|
    where('contract_end_date <= ?', date).where.not(contract_end_date: nil) if date.present?
  }
  scope :expired_contracts, -> { where('contract_end_date < ?', Date.current).where.not(contract_end_date: nil) }
  scope :recent_snapshot, -> { where(snapshot_date: (7.days.ago.to_date)..) }
  scope :by_player, -> { order(:player_external_name) }
  scope :free_agents, lambda {
    where(team_name: [nil, '']).or(where('contract_end_date < ?', Date.current))
  }
  scope :with_soloqueue, -> { where.not(solo_queue_id: [nil, '']) }

  def effective_solo_queue_id
    solo_queue_id_override.presence || solo_queue_id
  end

  def needs_tag_enrichment?
    solo_queue_id_override.blank? &&
      solo_queue_id.present? &&
      !solo_queue_id.include?('#') &&
      !tag_enriched &&
      RiotApiService::REGIONS.key?(solo_queue_server)
  end
end
