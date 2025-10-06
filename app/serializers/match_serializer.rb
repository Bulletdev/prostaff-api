class MatchSerializer < Blueprinter::Base
  identifier :id

  fields :match_type, :game_start, :game_end, :game_duration,
         :riot_match_id, :game_version,
         :opponent_name, :opponent_tag, :victory,
         :our_side, :our_score, :opponent_score,
         :our_towers, :opponent_towers, :our_dragons, :opponent_dragons,
         :our_barons, :opponent_barons, :our_inhibitors, :opponent_inhibitors,
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
