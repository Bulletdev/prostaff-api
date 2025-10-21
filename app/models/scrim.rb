class Scrim < ApplicationRecord
  # Concerns
  include Constants

  # Associations
  belongs_to :organization
  belongs_to :match, optional: true
  belongs_to :opponent_team, optional: true

  # Validations
  validates :scrim_type, inclusion: {
    in: Constants::Scrim::TYPES,
    message: "%{value} is not a valid scrim type"
  }, allow_blank: true

  validates :focus_area, inclusion: {
    in: Constants::Scrim::FOCUS_AREAS,
    message: "%{value} is not a valid focus area"
  }, allow_blank: true

  validates :visibility, inclusion: {
    in: Constants::Scrim::VISIBILITY_LEVELS,
    message: "%{value} is not a valid visibility level"
  }, allow_blank: true

  validates :games_planned, numericality: { greater_than: 0 }, allow_nil: true
  validates :games_completed, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :games_completed_not_greater_than_planned

  # Scopes
  scope :upcoming, -> { where('scheduled_at > ?', Time.current).order(scheduled_at: :asc) }
  scope :past, -> { where('scheduled_at <= ?', Time.current).order(scheduled_at: :desc) }
  scope :by_type, ->(type) { where(scrim_type: type) }
  scope :by_focus_area, ->(area) { where(focus_area: area) }
  scope :completed, -> { where.not(games_completed: nil).where('games_completed >= games_planned') }
  scope :in_progress, -> { where.not(games_completed: nil).where('games_completed < games_planned') }
  scope :confidential, -> { where(is_confidential: true) }
  scope :publicly_visible, -> { where(is_confidential: false) }
  scope :recent, ->(days = 30) { where('scheduled_at > ?', days.days.ago).order(scheduled_at: :desc) }

  # Instance methods
  def completion_percentage
    return 0 if games_planned.nil? || games_planned.zero?
    return 0 if games_completed.nil?

    ((games_completed.to_f / games_planned) * 100).round(2)
  end

  def status
    return 'upcoming' if scheduled_at.nil? || scheduled_at > Time.current

    if games_completed.nil? || games_completed.zero?
      'not_started'
    elsif games_completed >= (games_planned || 1)
      'completed'
    else
      'in_progress'
    end
  end

  def win_rate
    return 0 if game_results.blank?

    wins = game_results.count { |result| result['victory'] == true }
    total = game_results.size

    return 0 if total.zero?

    ((wins.to_f / total) * 100).round(2)
  end

  def add_game_result(victory:, duration: nil, notes: nil)
    result = {
      game_number: (game_results.size + 1),
      victory: victory,
      duration: duration,
      notes: notes,
      played_at: Time.current
    }

    self.game_results << result
    self.games_completed = (games_completed || 0) + 1

    save
  end

  def objectives_met?
    return false if objectives.blank? || outcomes.blank?

    objectives.keys.all? { |key| outcomes[key].present? }
  end

  private

  def games_completed_not_greater_than_planned
    return if games_planned.nil? || games_completed.nil?

    if games_completed > games_planned
      errors.add(:games_completed, "cannot be greater than games planned (#{games_planned})")
    end
  end
end
