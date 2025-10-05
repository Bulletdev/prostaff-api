class MatchSerializer < Blueprinter::Base
  identifier :id

  fields :match_type, :game_start, :game_end, :game_duration,
         :riot_match_id, :patch_version, :tournament_name, :stage,
         :opponent_name, :opponent_tag, :victory,
         :our_side, :our_score, :opponent_score,
         :first_blood, :first_tower, :first_baron, :first_dragon,
         :total_kills, :total_deaths, :total_assists, :total_gold,
         :vod_url, :replay_file_url, :notes,
         :created_at, :updated_at

  field :result do |match|
    match.result_text
  end

  field :duration_formatted do |match|
    match.duration_formatted
  end

  field :score_display do |match|
    match.score_display
  end

  field :kda_summary do |match|
    match.kda_summary
  end

  field :has_replay do |match|
    match.has_replay?
  end

  field :has_vod do |match|
    match.has_vod?
  end

  association :organization, blueprint: OrganizationSerializer
end
