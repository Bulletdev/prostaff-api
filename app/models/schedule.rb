class Schedule < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :match, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :event_type, presence: true, inclusion: { in: %w[match scrim practice meeting review] }
  validates :start_time, :end_time, presence: true
  validates :status, inclusion: { in: %w[scheduled ongoing completed cancelled] }
  validate :end_time_after_start_time

  # Callbacks
  before_save :set_timezone_if_blank
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :by_type, ->(type) { where(event_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :upcoming, -> { where('start_time > ?', Time.current) }
  scope :today, -> { where(start_time: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(start_time: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :in_date_range, ->(start_date, end_date) { where(start_time: start_date..end_date) }
  scope :for_player, ->(player_id) { where('? = ANY(required_players) OR ? = ANY(optional_players)', player_id, player_id) }

  # Instance methods
  def duration_minutes
    return 0 unless start_time && end_time

    ((end_time - start_time) / 1.minute).round
  end

  def duration_formatted
    minutes = duration_minutes
    hours = minutes / 60
    mins = minutes % 60

    if hours > 0
      "#{hours}h #{mins}m"
    else
      "#{mins}m"
    end
  end

  def status_color
    case status
    when 'scheduled' then 'blue'
    when 'ongoing' then 'green'
    when 'completed' then 'gray'
    when 'cancelled' then 'red'
    else 'gray'
    end
  end

  def is_today?
    start_time.to_date == Date.current
  end

  def is_upcoming?
    start_time > Time.current
  end

  def is_past?
    end_time < Time.current
  end

  def is_ongoing?
    Time.current.between?(start_time, end_time)
  end

  def can_be_cancelled?
    %w[scheduled].include?(status) && is_upcoming?
  end

  def can_be_completed?
    %w[scheduled ongoing].include?(status)
  end

  def required_player_names
    return [] if required_players.blank?

    Player.where(id: required_players).pluck(:summoner_name)
  end

  def optional_player_names
    return [] if optional_players.blank?

    Player.where(id: optional_players).pluck(:summoner_name)
  end

  def all_participants
    required_player_names + optional_player_names
  end

  def reminder_times
    return [] if reminder_minutes.blank?

    reminder_minutes.map do |minutes|
      start_time - minutes.minutes
    end
  end

  def next_reminder
    now = Time.current
    reminder_times.select { |time| time > now }.min
  end

  def conflict_with?(other_schedule)
    return false if other_schedule == self

    time_overlap?(other_schedule) && participant_overlap?(other_schedule)
  end

  def mark_as_completed!
    update!(status: 'completed')
  end

  def mark_as_cancelled!
    update!(status: 'cancelled')
  end

  def mark_as_ongoing!
    update!(status: 'ongoing')
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time

    errors.add(:end_time, 'must be after start time') if end_time <= start_time
  end

  def set_timezone_if_blank
    self.timezone = 'UTC' if timezone.blank?
  end

  def time_overlap?(other)
    start_time < other.end_time && end_time > other.start_time
  end

  def participant_overlap?(other)
    our_participants = required_players + optional_players
    other_participants = other.required_players + other.optional_players

    (our_participants & other_participants).any?
  end

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      action: 'update',
      entity_type: 'Schedule',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end
end