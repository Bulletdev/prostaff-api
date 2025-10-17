class UserSerializer < Blueprinter::Base

  identifier :id

  fields :email, :full_name, :role, :avatar_url, :timezone, :language,
         :notifications_enabled, :notification_preferences, :last_login_at,
         :created_at, :updated_at

  field :role_display do |user|
    user.full_role_name
  end

  field :permissions do |user|
    {
      can_manage_users: user.can_manage_users?,
      can_manage_players: user.can_manage_players?,
      can_view_analytics: user.can_view_analytics?,
      is_admin_or_owner: user.admin_or_owner?
    }
  end

  field :last_login_display do |user|
    user.last_login_at ? time_ago_in_words(user.last_login_at) : 'Never'
  end

  def self.time_ago_in_words(time)
    if time.nil?
      'Never'
    else
      diff = Time.current - time
      case diff
      when 0...60
        "#{diff.to_i} seconds ago"
      when 60...3600
        "#{(diff / 60).to_i} minutes ago"
      when 3600...86400
        "#{(diff / 3600).to_i} hours ago"
      when 86400...2592000
        "#{(diff / 86400).to_i} days ago"
      else
        time.strftime('%B %d, %Y')
      end
    end
  end
end