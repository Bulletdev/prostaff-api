class ScrimOpponentTeamSerializer
  def initialize(opponent_team, options = {})
    @opponent_team = opponent_team
    @options = options
  end

  def as_json
    base_attributes.tap do |hash|
      hash.merge!(detailed_attributes) if @options[:detailed]
    end
  end

  private

  def base_attributes
    {
      id: @opponent_team.id,
      name: @opponent_team.name,
      tag: @opponent_team.tag,
      full_name: @opponent_team.full_name,
      region: @opponent_team.region,
      tier: @opponent_team.tier,
      tier_display: @opponent_team.tier_display,
      league: @opponent_team.league,
      logo_url: @opponent_team.logo_url,
      total_scrims: @opponent_team.total_scrims,
      scrim_record: @opponent_team.scrim_record,
      scrim_win_rate: @opponent_team.scrim_win_rate,
      created_at: @opponent_team.created_at,
      updated_at: @opponent_team.updated_at
    }
  end

  def detailed_attributes
    {
      known_players: @opponent_team.known_players,
      recent_performance: @opponent_team.recent_performance,
      playstyle_notes: @opponent_team.playstyle_notes,
      strengths: @opponent_team.all_strengths_tags,
      weaknesses: @opponent_team.all_weaknesses_tags,
      preferred_champions: @opponent_team.preferred_champions,
      contact_email: @opponent_team.contact_email,
      discord_server: @opponent_team.discord_server,
      contact_available: @opponent_team.contact_available?
    }
  end
end
