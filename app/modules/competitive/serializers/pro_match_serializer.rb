module Competitive
  module Serializers
    class ProMatchSerializer < Blueprinter::Base
      identifier :id

      fields :tournament_name,
             :tournament_stage,
             :tournament_region,
             :match_date,
             :match_format,
             :game_number,
             :our_team_name,
             :opponent_team_name,
             :victory,
             :series_score,
             :side,
             :patch_version,
             :vod_url,
             :external_stats_url

      field :our_picks do |match|
        match.our_picks.presence || []
      end

      field :opponent_picks do |match|
        match.opponent_picks.presence || []
      end

      field :our_bans do |match|
        match.our_bans.presence || []
      end

      field :opponent_bans do |match|
        match.opponent_bans.presence || []
      end

      field :result do |match|
        match.result_text
      end

      field :tournament_display do |match|
        match.tournament_display
      end

      field :game_label do |match|
        match.game_label
      end

      field :has_complete_draft do |match|
        match.has_complete_draft?
      end

      field :meta_relevant do |match|
        match.meta_relevant?
      end

      field :created_at
      field :updated_at
    end
  end
end
