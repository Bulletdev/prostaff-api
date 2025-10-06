class VodReview < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :match, optional: true
  belongs_to :reviewer, class_name: 'User', optional: true
  has_many :vod_timestamps, dependent: :destroy

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :video_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
  validates :review_type, inclusion: { in: %w[team individual opponent] }, allow_blank: true
  validates :status, inclusion: { in: %w[draft published archived] }
  validates :share_link, uniqueness: true, allow_blank: true

  # Callbacks
  before_create :generate_share_link, if: -> { is_public? }
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_type, ->(type) { where(review_type: type) }
  scope :published, -> { where(status: 'published') }
  scope :public_reviews, -> { where(is_public: true) }
  scope :for_match, ->(match_id) { where(match_id: match_id) }
  scope :recent, ->(days = 30) { where(created_at: days.days.ago..Time.current) }

  # Instance methods
  def duration_formatted
    return 'Unknown' if duration.blank?

    hours = duration / 3600
    minutes = (duration % 3600) / 60
    seconds = duration % 60

    if hours > 0
      "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
    else
      "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
    end
  end

  def status_color
    case status
    when 'draft' then 'yellow'
    when 'published' then 'green'
    when 'archived' then 'gray'
    else 'gray'
    end
  end

  def can_be_edited_by?(user)
    reviewer == user || user.admin_or_owner?
  end

  def can_be_viewed_by?(user)
    return true if is_public?
    return true if reviewer == user || user.admin_or_owner?

    shared_with_players.include?(user.id)
  end

  def shared_player_names
    return [] if shared_with_players.blank?

    Player.where(id: shared_with_players).pluck(:summoner_name)
  end

  def timestamp_count
    vod_timestamps.count
  end

  def timestamp_categories
    vod_timestamps.group(:category).count
  end

  def important_timestamps
    vod_timestamps.where(importance: %w[high critical]).order(:timestamp_seconds)
  end

  def publish!
    update!(
      status: 'published',
      share_link: generate_share_link_value
    )
  end

  def archive!
    update!(status: 'archived')
  end

  def make_public!
    update!(
      is_public: true,
      share_link: share_link.presence || generate_share_link_value
    )
  end

  def make_private!
    update!(is_public: false)
  end

  def share_with_player!(player_id)
    return if shared_with_players.include?(player_id)

    update!(shared_with_players: shared_with_players + [player_id])
  end

  def unshare_with_player!(player_id)
    update!(shared_with_players: shared_with_players - [player_id])
  end

  def share_with_all_players!
    player_ids = organization.players.pluck(:id)
    update!(shared_with_players: player_ids)
  end

  def public_url
    return nil unless is_public? && share_link.present?

    "#{ENV['FRONTEND_URL']}/vod-reviews/#{share_link}"
  end

  private

  def generate_share_link
    self.share_link = generate_share_link_value
  end

  def generate_share_link_value
    SecureRandom.urlsafe_base64(16)
  end

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      action: 'update',
      entity_type: 'VodReview',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end
end