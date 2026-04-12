# frozen_string_literal: true

# Serializes a TournamentTeam. Use with_roster: true to include locked roster snapshot.
class TournamentTeamSerializer
  def initialize(team, options = {})
    @team    = team
    @options = options
  end

  def as_json
    base.tap do |h|
      h[:roster] = serialize_roster if @options[:with_roster]
    end
  end

  private

  def base
    {
      id: @team.id,
      tournament_id: @team.tournament_id,
      organization_id: @team.organization_id,
      team_name: @team.team_name,
      team_tag: @team.team_tag,
      logo_url: @team.logo_url,
      status: @team.status,
      seed: @team.seed,
      bracket_side: @team.bracket_side,
      enrolled_at: @team.enrolled_at&.iso8601,
      approved_at: @team.approved_at&.iso8601,
      rejected_at: @team.rejected_at&.iso8601
    }
  end

  def serialize_roster
    @team.tournament_roster_snapshots.map do |s|
      {
        player_id: s.player_id,
        summoner_name: s.summoner_name,
        role: s.role,
        position: s.position,
        locked_at: s.locked_at.iso8601
      }
    end
  end
end
