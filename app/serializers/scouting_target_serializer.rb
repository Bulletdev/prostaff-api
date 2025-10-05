class ScoutingTargetSerializer < Blueprinter::Base
  identifier :id

  fields :summoner_name, :real_name, :role, :current_team,
         :region, :nationality, :age, :status,
         :solo_queue_tier, :solo_queue_rank, :solo_queue_lp,
         :peak_tier, :peak_rank,
         :riot_puuid, :riot_summoner_id,
         :scouting_notes, :interest_level, :contacted,
         :contact_notes, :availability, :salary_expectations,
         :twitter_handle, :twitch_channel,
         :last_sync_at, :created_at, :updated_at

  field :interest_level_text do |target|
    case target.interest_level
    when 1 then 'Low'
    when 2 then 'Medium'
    when 3 then 'High'
    when 4 then 'Very High'
    when 5 then 'Priority'
    else 'Not Rated'
    end
  end

  association :organization, blueprint: OrganizationSerializer
  association :added_by, blueprint: UserSerializer
end
