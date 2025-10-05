class TeamGoalSerializer < Blueprinter::Base
  identifier :id

  fields :title, :description, :category, :metric_type,
         :target_value, :current_value, :start_date, :end_date,
         :status, :progress, :notes, :created_at, :updated_at

  field :is_team_goal do |goal|
    goal.is_team_goal?
  end

  field :days_remaining do |goal|
    goal.days_remaining
  end

  field :days_total do |goal|
    goal.days_total
  end

  field :time_progress_percentage do |goal|
    goal.time_progress_percentage
  end

  field :is_overdue do |goal|
    goal.is_overdue?
  end

  field :target_display do |goal|
    goal.target_display
  end

  field :current_display do |goal|
    goal.current_display
  end

  field :completion_percentage do |goal|
    goal.completion_percentage
  end

  association :organization, blueprint: OrganizationSerializer
  association :player, blueprint: PlayerSerializer
  association :assigned_to, blueprint: UserSerializer
  association :created_by, blueprint: UserSerializer
end
