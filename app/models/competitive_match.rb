class CompetitiveMatch < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :opponent_team, optional: true
  belongs_to :match, optional: true # Link to internal match record if available

  # Validations
  validates :tournament_name, presence: true
  validates :external_match_id, uniqueness: true, allow_blank: true

  validates :match_format, inclusion: {
    in: %w[BO1 BO3 BO5],
    message: "%{value} is not a valid match format"
  }, allow_blank: true

  validates :side, inclusion: {
    in: %w[blue red],
    message: "%{value} is not a valid side"
  }, allow_blank: true

  validates :game_number, numericality: {
    greater_than: 0, less_than_or_equal_to: 5
  }, allow_nil: true

  # Callbacks
  after_create :log_competitive_match_created
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :by_tournament, ->(tournament) { where(tournament_name: tournament) }
  scope :by_region, ->(region) { where(tournament_region: region) }
  scope :by_stage, ->(stage) { where(tournament_stage: stage) }
  scope :by_patch, ->(patch) { where(patch_version: patch) }
  scope :victories, -> { where(victory: true) }
  scope :defeats, -> { where(victory: false) }
  scope :recent, ->(days = 30) { where('match_date > ?', days.days.ago).order(match_date: :desc) }
  scope :blue_side, -> { where(side: 'blue') }
  scope :red_side, -> { where(side: 'red') }
  scope :in_date_range, ->(start_date, end_date) { where(match_date: start_date..end_date) }
  scope :ordered_by_date, -> { order(match_date: :desc) }

  # Instance methods
  def result_text
    return 'Unknown' if victory.nil?

    victory? ? 'Victory' : 'Defeat'
  end

  def tournament_display
    if tournament_stage.present?
      "#{tournament_name} - #{tournament_stage}"
    else
      tournament_name
    end
  end

  def game_label
    if game_number.present? && match_format.present?
      "#{match_format} - Game #{game_number}"
    elsif match_format.present?
      match_format
    else
      'Competitive Match'
    end
  end

  def draft_summary
    {
      our_bans: our_bans.presence || [],
      opponent_bans: opponent_bans.presence || [],
      our_picks: our_picks.presence || [],
      opponent_picks: opponent_picks.presence || [],
      side: side
    }
  end

  def our_composition
    our_picks.presence || []
  end

  def opponent_composition
    opponent_picks.presence || []
  end

  def total_bans
    (our_bans.size + opponent_bans.size)
  end

  def total_picks
    (our_picks.size + opponent_picks.size)
  end

  def has_complete_draft?
    our_picks.size == 5 && opponent_picks.size == 5
  end

  def our_banned_champions
    our_bans.map { |ban| ban['champion'] }.compact
  end

  def opponent_banned_champions
    opponent_bans.map { |ban| ban['champion'] }.compact
  end

  def our_picked_champions
    our_picks.map { |pick| pick['champion'] }.compact
  end

  def opponent_picked_champions
    opponent_picks.map { |pick| pick['champion'] }.compact
  end

  def champion_picked_by_role(role, team: 'ours')
    picks = team == 'ours' ? our_picks : opponent_picks
    pick = picks.find { |p| p['role']&.downcase == role.downcase }
    pick&.dig('champion')
  end

  def meta_relevant?
    return false if meta_champions.blank?

    our_champions = our_picked_champions
    meta_count = (our_champions & meta_champions).size

    meta_count >= 2 # At least 2 meta champions
  end

  def is_current_patch?(current_patch = nil)
    return false if patch_version.blank?
    return true if current_patch.nil?

    patch_version == current_patch
  end

  # Analysis methods
  def draft_phase_sequence
    # Returns the complete draft sequence combining bans and picks
    sequence = []

    # Combine bans and picks with timestamps/order if available
    our_bans.each do |ban|
      sequence << { team: 'ours', type: 'ban', **ban.symbolize_keys }
    end

    opponent_bans.each do |ban|
      sequence << { team: 'opponent', type: 'ban', **ban.symbolize_keys }
    end

    our_picks.each do |pick|
      sequence << { team: 'ours', type: 'pick', **pick.symbolize_keys }
    end

    opponent_picks.each do |pick|
      sequence << { team: 'opponent', type: 'pick', **pick.symbolize_keys }
    end

    # Sort by order if available
    sequence.sort_by { |item| item[:order] || 0 }
  end

  def first_rotation_bans
    our_bans.select { |ban| (ban['order'] || 0) <= 3 }
  end

  def second_rotation_bans
    our_bans.select { |ban| (ban['order'] || 0) > 3 }
  end

  private

  def log_competitive_match_created
    AuditLog.create!(
      organization: organization,
      action: 'create',
      entity_type: 'CompetitiveMatch',
      entity_id: id,
      new_values: attributes
    )
  rescue StandardError => e
    Rails.logger.error("Failed to create audit log for competitive match #{id}: #{e.message}")
  end

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      action: 'update',
      entity_type: 'CompetitiveMatch',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  rescue StandardError => e
    Rails.logger.error("Failed to update audit log for competitive match #{id}: #{e.message}")
  end
end
