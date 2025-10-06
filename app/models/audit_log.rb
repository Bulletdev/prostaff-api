class AuditLog < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :user, optional: true

  # Validations
  validates :action, presence: true
  validates :entity_type, presence: true

  # Scopes
  scope :by_action, ->(action) { where(action: action) }
  scope :by_entity_type, ->(type) { where(entity_type: type) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, ->(days = 30) { where(created_at: days.days.ago..Time.current) }
  scope :for_entity, ->(type, id) { where(entity_type: type, entity_id: id) }

  # Instance methods
  def action_display
    action.humanize
  end

  def user_display
    user&.full_name || user&.email || 'System'
  end

  def entity_display
    "#{entity_type} ##{entity_id}"
  end

  def changes_summary
    return 'Created' if action == 'create'
    return 'Deleted' if action == 'delete'

    return 'No changes recorded' if old_values.blank? && new_values.blank?

    changes = []

    if old_values.present? && new_values.present?
      new_values.each do |key, new_val|
        old_val = old_values[key]
        next if old_val == new_val

        changes << "#{key.humanize}: #{format_value(old_val)} → #{format_value(new_val)}"
      end
    end

    changes.empty? ? 'No changes recorded' : changes.join(', ')
  end

  def ip_location
    # This could be enhanced with a GeoIP service
    return 'Unknown' if ip_address.blank?

    if ip_address.to_s.start_with?('127.0.0.1', '::1')
      'Local'
    elsif ip_address.to_s.start_with?('192.168.', '10.', '172.')
      'Private Network'
    else
      'External'
    end
  end

  def browser_info
    return 'Unknown' if user_agent.blank?

    # Simple browser detection
    case user_agent
    when /Chrome/i then 'Chrome'
    when /Firefox/i then 'Firefox'
    when /Safari/i then 'Safari'
    when /Edge/i then 'Edge'
    when /Opera/i then 'Opera'
    else 'Unknown Browser'
    end
  end

  def time_ago
    time_diff = Time.current - created_at

    case time_diff
    when 0...60
      "#{time_diff.to_i} seconds ago"
    when 60...3600
      "#{(time_diff / 60).to_i} minutes ago"
    when 3600...86400
      "#{(time_diff / 3600).to_i} hours ago"
    when 86400...2592000
      "#{(time_diff / 86400).to_i} days ago"
    else
      created_at.strftime('%B %d, %Y')
    end
  end

  def risk_level
    case action
    when 'delete' then 'high'
    when 'update' then 'medium'
    when 'create' then 'low'
    when 'login', 'logout' then 'info'
    else 'medium'
    end
  end

  def risk_color
    case risk_level
    when 'high' then 'red'
    when 'medium' then 'orange'
    when 'low' then 'green'
    when 'info' then 'blue'
    else 'gray'
    end
  end

  def self.log_action(organization:, user: nil, action:, entity_type:, entity_id: nil, old_values: {}, new_values: {}, ip: nil, user_agent: nil)
    create!(
      organization: organization,
      user: user,
      action: action,
      entity_type: entity_type,
      entity_id: entity_id,
      old_values: old_values,
      new_values: new_values,
      ip_address: ip,
      user_agent: user_agent
    )
  end

  def self.security_events
    where(action: %w[login logout failed_login password_reset])
  end

  def self.data_changes
    where(action: %w[create update delete])
  end

  def self.high_risk_actions
    where(action: %w[delete user_role_change organization_settings_change])
  end

  private

  def format_value(value)
    case value
    when nil then 'nil'
    when true then 'true'
    when false then 'false'
    when String
      value.length > 50 ? "#{value[0..47]}..." : value
    else
      value.to_s
    end
  end
end