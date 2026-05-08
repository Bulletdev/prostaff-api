# frozen_string_literal: true

# Serializer for AvailabilityWindow model using Blueprinter.
class AvailabilityWindowSerializer < Blueprinter::Base
  identifier :id

  fields :day_of_week, :start_hour, :end_hour, :timezone,
         :game, :region, :tier_preference, :focus_area, :draft_type, :active, :expires_at,
         :created_at, :updated_at

  field :day_name do |window|
    window.day_name
  end

  field :time_range do |window|
    window.time_range_display
  end

  field :duration_hours do |window|
    window.duration_hours
  end

  field :expired do |window|
    window.expired?
  end
end
