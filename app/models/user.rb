class User < ApplicationRecord
  has_secure_password

  # Associations
  belongs_to :organization
  has_many :added_scouting_targets, class_name: 'ScoutingTarget', foreign_key: 'added_by_id', dependent: :nullify
  has_many :assigned_scouting_targets, class_name: 'ScoutingTarget', foreign_key: 'assigned_to_id', dependent: :nullify
  has_many :created_schedules, class_name: 'Schedule', foreign_key: 'created_by_id', dependent: :nullify
  has_many :reviewed_vods, class_name: 'VodReview', foreign_key: 'reviewer_id', dependent: :nullify
  has_many :created_vod_timestamps, class_name: 'VodTimestamp', foreign_key: 'created_by_id', dependent: :nullify
  has_many :assigned_goals, class_name: 'TeamGoal', foreign_key: 'assigned_to_id', dependent: :nullify
  has_many :created_goals, class_name: 'TeamGoal', foreign_key: 'created_by_id', dependent: :nullify
  has_many :audit_logs, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :full_name, length: { maximum: 255 }
  validates :role, presence: true, inclusion: { in: %w[owner admin coach analyst viewer] }
  validates :timezone, length: { maximum: 100 }
  validates :language, length: { maximum: 10 }

  # Callbacks
  before_save :downcase_email
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :active, -> { where.not(last_login_at: nil) }

  # Instance methods
  def admin_or_owner?
    %w[admin owner].include?(role)
  end

  def can_manage_users?
    %w[owner admin].include?(role)
  end

  def can_manage_players?
    %w[owner admin coach].include?(role)
  end

  def can_view_analytics?
    %w[owner admin coach analyst].include?(role)
  end

  def full_role_name
    role.titleize
  end

  def update_last_login!
    update_column(:last_login_at, Time.current)
  end

  private

  def downcase_email
    self.email = email.downcase.strip if email.present?
  end

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      user: self,
      action: 'update',
      entity_type: 'User',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end
end