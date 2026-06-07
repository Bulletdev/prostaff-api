# frozen_string_literal: true

# Authenticated user within an organization, with role-based access and notification support.
class User < ApplicationRecord
  # Concerns
  include Constants
  include UpgradeablePassword

  # Associations
  belongs_to :organization
  has_many :added_scouting_targets, class_name: 'ScoutingTarget', foreign_key: 'added_by_id', dependent: :nullify
  has_many :assigned_scouting_targets, class_name: 'ScoutingTarget', foreign_key: 'assigned_to_id', dependent: :nullify
  has_many :created_schedules, class_name: 'Schedule', foreign_key: 'created_by_id', dependent: :nullify
  has_many :reviewed_vods, class_name: 'VodReview', foreign_key: 'reviewer_id', dependent: :nullify
  has_many :created_vod_timestamps, class_name: 'VodTimestamp', foreign_key: 'created_by_id', dependent: :nullify
  has_many :assigned_goals, class_name: 'TeamGoal', foreign_key: 'assigned_to_id', dependent: :nullify
  has_many :created_goals, class_name: 'TeamGoal', foreign_key: 'created_by_id', dependent: :nullify
  has_many :notifications, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :password_reset_tokens, dependent: :destroy
  has_many :messages, dependent: :nullify

  # Virtual password attribute — set when changing password, nil otherwise.
  # has_secure_password is not used; hashing is handled by Authentication::PasswordHasher.
  attr_reader :password

  def password=(plain_password)
    @password = plain_password.blank? ? nil : plain_password
  end

  def authenticate(plain_password)
    authenticate_with_upgrade(
      plain_password,
      digest_attr: :password_digest,
      digest_setter: :password_digest
    )
  end

  # Validations
  validates :password_digest, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :full_name, presence: true, length: { maximum: 255 }
  validates :role, presence: true, inclusion: { in: Constants::User::ROLES }
  validates :source_app, inclusion: { in: Constants::SOURCE_APPS }
  validates :timezone, length: { maximum: 100 }
  validates :language, length: { maximum: 10 }
  validates :discord_user_id,
            uniqueness: { allow_blank: true },
            format: { with: /\A\d{17,20}\z/, message: 'must be a valid Discord user ID (17–20 digits)',
                      allow_blank: true }
  validates :password,
            length: { minimum: 8, message: 'must be at least 8 characters' },
            format: {
              with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).*\z/,
              message: 'must contain at least one uppercase letter, one lowercase letter, and one number'
            },
            if: -> { password.present? }

  # Callbacks
  before_validation :downcase_email
  before_validation :hash_password, if: -> { password.present? }
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :active, -> { where.not(last_login_at: nil) }

  # Instance methods
  def admin?
    role == 'admin'
  end

  def owner?
    role == 'owner'
  end

  def manager?
    role == 'manager'
  end

  def admin_or_owner?
    %w[admin owner].include?(role)
  end

  def support_staff?
    role == 'support_staff'
  end

  def can_manage_org?
    %w[owner admin manager].include?(role)
  end

  def can_manage_users?
    %w[owner admin].include?(role)
  end

  def can_manage_players?
    %w[owner admin manager coach].include?(role)
  end

  def can_view_analytics?
    %w[owner admin manager coach analyst].include?(role)
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

  def hash_password
    self.password_digest = Authentication::PasswordHasher.hash(password)
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
