class PlayerMatchStatSerializer < Blueprinter::Base
  identifier :id

  fields :role, :champion, :kills, :deaths, :assists,
         :gold_earned, :total_damage_dealt, :total_damage_taken,
         :minions_killed, :jungle_minions_killed,
         :vision_score, :wards_placed, :wards_killed,
         :champion_level, :first_blood_kill, :double_kills,
         :triple_kills, :quadra_kills, :penta_kills,
         :performance_score, :created_at, :updated_at

  field :kda do |stat|
    deaths = stat.deaths.zero? ? 1 : stat.deaths
    ((stat.kills + stat.assists).to_f / deaths).round(2)
  end

  field :cs_total do |stat|
    (stat.minions_killed || 0) + (stat.jungle_minions_killed || 0)
  end

  association :player, blueprint: PlayerSerializer
  association :match, blueprint: MatchSerializer
end
