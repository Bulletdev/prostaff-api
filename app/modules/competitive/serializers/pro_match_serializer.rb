# frozen_string_literal: true

# Serializes professional match records including draft, scores, and VOD links.
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

  field :our_team_logo do |match|
    match.organization&.logo_url
  end

  field :opponent_team_logo do |match|
    # Prefer the linked OpponentTeam record if populated
    explicit = match.opponent_team&.logo_url
    return explicit if explicit.present?

    # Fall back to image stored in game_stats during ES import
    stats = match.game_stats || {}
    our_is_team1 = stats['team1_name'].to_s.strip.downcase == match.our_team_name.to_s.strip.downcase
    our_is_team1 ? stats['team2_image'] : stats['team1_image']
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
