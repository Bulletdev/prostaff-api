class ScoutingTargetSerializer < Blueprinter::Base
  identifier :id

  fields :summoner_name, :role, :region, :status, :priority, :age

  fields :riot_puuid

  fields :current_tier, :current_rank, :current_lp

  fields :champion_pool, :playstyle, :strengths, :weaknesses

  fields :recent_performance, :performance_trend

  fields :email, :phone, :discord_username, :twitter_handle

  fields :notes, :metadata

  fields :last_reviewed, :created_at, :updated_at

  field :priority_text do |target|
    target.priority&.titleize || 'Not Set'
  end

  field :status_text do |target|
    target.status&.titleize || 'Watching'
  end

  field :current_rank_display do |target|
    target.current_rank_display
  end

  association :organization, blueprint: OrganizationSerializer
  association :added_by, blueprint: UserSerializer
  association :assigned_to, blueprint: UserSerializer
end
