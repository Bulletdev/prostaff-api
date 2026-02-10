# frozen_string_literal: true

# DraftPlan model
# Stores pre-planned draft strategies with if-then scenarios
# Allows coaches to prepare counter-picks and bans against specific opponents
class DraftPlan < ApplicationRecord
  # Concerns
  include OrganizationScoped
  include Constants

  # Associations
  belongs_to :organization
  belongs_to :created_by, class_name: 'User'
  belongs_to :updated_by, class_name: 'User'

  # Validations
  validates :opponent_team, presence: true, length: { maximum: 100 }
  validates :side, presence: true, inclusion: { in: Constants::Match::SIDES }
  validates :patch_version, format: { with: /\A\d+\.\d+\z/ }, allow_blank: true

  # Validate JSON structures
  validate :validate_bans_structure
  validate :validate_priority_picks_structure
  validate :validate_scenarios_structure

  # Callbacks
  before_save :normalize_champion_names
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_opponent, ->(opponent) { where('opponent_team ILIKE ?', "%#{opponent}%") }
  scope :by_side, ->(side) { where(side: side) }
  scope :by_patch, ->(patch) { where(patch_version: patch) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def side_display
    Constants::Match::SIDE_NAMES[side] || side.titleize
  end

  def total_scenarios
    if_then_scenarios&.size || 0
  end

  def priority_champions
    priority_picks.values.compact
  end

  # Add a new if-then scenario
  # @param trigger [String] The trigger condition (e.g., "enemy_bans_leblanc")
  # @param action [String] The action to take (e.g., "pick_ahri")
  # @param note [String] Additional notes about the scenario
  def add_scenario(trigger:, action:, note: nil)
    self.if_then_scenarios ||= []
    self.if_then_scenarios << {
      trigger: trigger,
      action: action,
      note: note,
      created_at: Time.current.iso8601
    }
  end

  # Remove a scenario by index
  def remove_scenario(index)
    return false unless if_then_scenarios.is_a?(Array)

    if_then_scenarios.delete_at(index)
  end

  # Set priority pick for a specific role
  # @param role [String] The role (top, jungle, mid, adc, support)
  # @param champion [String] The champion name
  def set_priority_pick(role:, champion:)
    self.priority_picks ||= {}
    self.priority_picks[role] = champion
  end

  # Get comfort picks from scouting data for opponent
  # This integrates with the scouting system
  def opponent_comfort_picks
    return [] unless opponent_team.present?

    # Find scouting targets matching the opponent team
    sanitized_team = ActiveRecord::Base.sanitize_sql_like(opponent_team)
    ScoutingTarget
      .where(organization: organization)
      .where('current_team ILIKE ?', "%#{sanitized_team}%")
      .pluck(:champion_pool)
      .flatten
      .uniq
  end

  # Analyze draft plan and suggest improvements
  def analyze
    {
      total_scenarios: total_scenarios,
      coverage: scenario_coverage,
      comfort_picks_covered: comfort_picks_coverage,
      suggested_bans: suggest_bans,
      blind_pick_ready: blind_pick_ready?
    }
  end

  def deactivate!
    update!(is_active: false)
  end

  def activate!
    update!(is_active: true)
  end

  private

  def validate_bans_structure
    return if our_bans.blank?

    unless our_bans.is_a?(Array) && our_bans.all? { |b| b.is_a?(String) }
      errors.add(:our_bans, 'must be an array of strings')
    end

    errors.add(:our_bans, 'cannot exceed 5 bans') if our_bans.size > 5
  end

  def validate_priority_picks_structure
    return if priority_picks.blank?

    unless priority_picks.is_a?(Hash)
      errors.add(:priority_picks, 'must be a hash')
      return
    end

    priority_picks.each do |role, champion|
      unless Constants::Player::ROLES.include?(role)
        errors.add(:priority_picks, "invalid role: #{role}")
      end
      unless champion.is_a?(String)
        errors.add(:priority_picks, "champion must be a string for role #{role}")
      end
    end
  end

  def validate_scenarios_structure
    return if if_then_scenarios.blank?

    unless if_then_scenarios.is_a?(Array)
      errors.add(:if_then_scenarios, 'must be an array')
      return
    end

    if_then_scenarios.each_with_index do |scenario, index|
      unless scenario.is_a?(Hash) && scenario['trigger'] && scenario['action']
        errors.add(:if_then_scenarios, "scenario at index #{index} must have trigger and action")
      end
    end
  end

  def normalize_champion_names
    self.our_bans = our_bans.map(&:strip) if our_bans.is_a?(Array)
    self.opponent_bans = opponent_bans.map(&:strip) if opponent_bans.is_a?(Array)

    return unless priority_picks.is_a?(Hash)

    self.priority_picks = priority_picks.transform_values(&:strip)
  end

  # Calculate what percentage of possible scenarios are covered
  def scenario_coverage
    return 0 if total_scenarios.zero?

    # Simplified coverage calculation
    # In a real scenario, this would analyze ban combinations
    [((total_scenarios / 10.0) * 100).round(2), 100].min
  end

  # Check how many opponent comfort picks are banned
  def comfort_picks_coverage
    comfort = opponent_comfort_picks
    return 100 if comfort.empty?

    banned = (our_bans & comfort).size
    ((banned.to_f / comfort.size) * 100).round(2)
  end

  # Suggest additional bans based on opponent comfort picks
  def suggest_bans
    comfort = opponent_comfort_picks
    already_banned = our_bans || []

    (comfort - already_banned).first(5)
  end

  # Check if we have priority picks for all roles
  def blind_pick_ready?
    Constants::Player::ROLES.all? { |role| priority_picks&.key?(role) }
  end

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      action: 'update',
      entity_type: 'DraftPlan',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end
end
