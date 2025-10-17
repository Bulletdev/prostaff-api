class ChampionPoolSerializer < Blueprinter::Base
  identifier :id

  fields :champion, :games_played, :wins, :losses,
         :average_kda, :average_cs, :mastery_level, :mastery_points,
         :last_played_at, :created_at, :updated_at

  field :win_rate do |pool|
    return 0 if pool.games_played.to_i.zero?
    ((pool.wins.to_f / pool.games_played) * 100).round(1)
  end

  association :player, blueprint: PlayerSerializer
end
