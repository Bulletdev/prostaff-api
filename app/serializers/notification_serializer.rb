# frozen_string_literal: true

class NotificationSerializer < Blueprinter::Base
  identifier :id

  fields :title, :message, :type
  fields :link_url, :link_type, :link_id
  fields :is_read, :read_at
  fields :channels, :email_sent, :discord_sent
  fields :metadata
  fields :created_at, :updated_at

  field :time_ago do |notification|
    time_diff = Time.current - notification.created_at

    case time_diff
    when 0..59
      "#{time_diff.to_i} seconds ago"
    when 60..3599
      "#{(time_diff / 60).to_i} minutes ago"
    when 3600..86_399
      "#{(time_diff / 3600).to_i} hours ago"
    when 86_400..604_799
      "#{(time_diff / 86_400).to_i} days ago"
    else
      notification.created_at.strftime('%d/%m/%Y')
    end
  end

  association :user, blueprint: UserSerializer
end
