# frozen_string_literal: true

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

      field :result, &:result_text

      field :tournament_display, &:tournament_display

      field :game_label, &:game_label

      field :has_complete_draft, &:has_complete_draft?

      field :meta_relevant, &:meta_relevant?

      field :created_at
      field :updated_at
    end
  end
end
