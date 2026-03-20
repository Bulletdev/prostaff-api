# frozen_string_literal: true

# Serializer for ChampionPool model
# Renders champion pool statistics for API responses
class ChampionPoolSerializer < Blueprinter::Base
  identifier :id

  fields :champion, :games_played, :games_won,
         :average_kda, :average_cs_per_min, :mastery_level,
         :last_played, :created_at, :updated_at

  field :losses do |pool|
    pool.games_played.to_i - pool.games_won.to_i
  end

  field :win_rate do |pool|
    return 0 if pool.games_played.to_i.zero?

    ((pool.games_won.to_f / pool.games_played) * 100).round(1)
  end

  association :player, blueprint: PlayerSerializer
end
