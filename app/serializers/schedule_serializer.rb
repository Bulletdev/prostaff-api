class ScheduleSerializer < Blueprinter::Base
  identifier :id

  fields :event_type, :title, :description, :start_time, :end_time,
         :location, :is_online, :opponent_name,
         :tournament_name, :stage, :status,
         :notes, :created_at, :updated_at

  field :duration_hours do |schedule|
    return nil unless schedule.start_time && schedule.end_time
    ((schedule.end_time - schedule.start_time) / 3600).round(1)
  end

  association :organization, blueprint: OrganizationSerializer
  association :match, blueprint: MatchSerializer
end
