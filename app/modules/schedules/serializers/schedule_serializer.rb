class ScheduleSerializer < Blueprinter::Base
  identifier :id

  fields :event_type, :title, :description, :start_time, :end_time,
         :location, :opponent_name, :status,
         :meeting_url, :timezone, :all_day,
         :tags, :color, :is_recurring, :recurrence_rule,
         :recurrence_end_date, :reminder_minutes,
         :required_players, :optional_players, :metadata,
         :created_at, :updated_at

  field :duration_hours do |schedule|
    return nil unless schedule.start_time && schedule.end_time
    ((schedule.end_time - schedule.start_time) / 3600).round(1)
  end

  association :organization, blueprint: OrganizationSerializer
  association :match, blueprint: MatchSerializer
end
