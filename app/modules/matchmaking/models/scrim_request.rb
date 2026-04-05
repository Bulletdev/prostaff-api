class ScrimRequest < ApplicationRecord
  STATUSES = %w[pending accepted declined expired cancelled].freeze
  GAMES = %w[league_of_legends valorant cs2 dota2].freeze

  # NOT org-scoped — spans two organizations
  belongs_to :requesting_organization, class_name: 'Organization'
  belongs_to :target_organization, class_name: 'Organization'
  belongs_to :availability_window, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :game, inclusion: { in: GAMES }
  validate :different_organizations

  scope :pending, -> { where(status: 'pending').where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :for_organization, ->(org_id) {
    where('requesting_organization_id = ? OR target_organization_id = ?', org_id, org_id)
  }
  scope :sent_by, ->(org_id) { where(requesting_organization_id: org_id) }
  scope :received_by, ->(org_id) { where(target_organization_id: org_id) }
  scope :recent, -> { order(created_at: :desc) }

  def pending?
    status == 'pending' && (expires_at.nil? || expires_at > Time.current)
  end

  def accepted?
    status == 'accepted'
  end

  def expired?
    (status == 'pending' && expires_at.present? && expires_at <= Time.current) || status == 'expired'
  end

  def accept!(accepting_org:)
    return false unless pending?
    return false unless accepting_org.id == target_organization_id

    ActiveRecord::Base.transaction do
      update!(status: 'accepted')
      create_scrims_for_both_orgs!
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def decline!(declining_org:)
    return false unless pending?
    return false unless declining_org.id == target_organization_id

    update!(status: 'declined')
  end

  def cancel!(cancelling_org:)
    return false unless pending?
    return false unless cancelling_org.id == requesting_organization_id

    update!(status: 'cancelled')
  end

  private

  def different_organizations
    return unless requesting_organization_id.present? && target_organization_id.present?
    if requesting_organization_id == target_organization_id
      errors.add(:target_organization, 'cannot be the same as requesting organization')
    end
  end

  def create_scrims_for_both_orgs!
    # Ensure opponent teams exist in each org's context
    req_opponent = find_or_create_opponent_team(for_org: requesting_organization, opponent: target_organization)
    tgt_opponent = find_or_create_opponent_team(for_org: target_organization, opponent: requesting_organization)

    # Create scrim for requesting org
    req_scrim = create_scrim_for_org(
      organization: requesting_organization,
      opponent_team: req_opponent
    )

    # Create scrim for target org
    tgt_scrim = create_scrim_for_org(
      organization: target_organization,
      opponent_team: tgt_opponent
    )

    update_columns(
      requesting_scrim_id: req_scrim.id,
      target_scrim_id: tgt_scrim.id
    )
  end

  def find_or_create_opponent_team(for_org:, opponent:)
    OpponentTeam.unscoped.find_or_create_by!(name: opponent.name) do |t|
      t.tag = opponent.slug&.upcase&.first(5)
      t.region = opponent.region
      t.tier = map_subscription_to_tier(opponent.subscription_plan)
    end
  rescue ActiveRecord::RecordNotUnique
    OpponentTeam.unscoped.find_by!(name: opponent.name)
  end

  def create_scrim_for_org(organization:, opponent_team:)
    Scrim.unscoped.create!(
      organization: organization,
      opponent_team: opponent_team,
      scheduled_at: proposed_at || Time.current,
      scrim_type: 'practice',
      visibility: 'full_team',
      games_planned: games_planned || 3,
      draft_type: draft_type,
      source: 'scrims_lol',
      scrim_request_id: id
    )
  end

  def map_subscription_to_tier(plan)
    case plan
    when 'professional', 'enterprise' then 'tier_1'
    when 'semi_pro'                   then 'tier_2'
    else                                   'tier_3'
    end
  end
end
