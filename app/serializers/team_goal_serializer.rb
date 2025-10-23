# frozen_string_literal: true

class TeamGoalSerializer < Blueprinter::Base
  identifier :id

  fields :title, :description, :category, :metric_type,
         :target_value, :current_value, :start_date, :end_date,
         :status, :progress, :created_at, :updated_at

  field :is_team_goal do |obj|

    obj.is_team_goal?

  end

  field :days_remaining do |obj|

    obj.days_remaining

  end

  field :days_total do |obj|

    obj.days_total

  end

  field :time_progress_percentage do |obj|

    obj.time_progress_percentage

  end

  field :is_overdue do |obj|

    obj.is_overdue?

  end

  field :target_display do |obj|

    obj.target_display

  end

  field :current_display do |obj|

    obj.current_display

  end

  field :completion_percentage do |obj|

    obj.completion_percentage

  end

  association :organization, blueprint: OrganizationSerializer
  association :player, blueprint: PlayerSerializer
  association :assigned_to, blueprint: UserSerializer
  association :created_by, blueprint: UserSerializer
end
