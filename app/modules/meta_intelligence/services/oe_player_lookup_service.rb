# frozen_string_literal: true

# Looks up Oracle's Elixir stats for a player or team by professional name.
class OePlayerLookupService
  # Returns the most recent stat record for a given professional name.
  def self.latest_stats(professional_name)
    return nil if professional_name.blank?

    TournamentPlayerStat
      .by_professional_name(professional_name)
      .order(year: :desc, computed_at: :desc)
      .first
  end

  # Returns all tournament history for a player, most recent first.
  def self.history(professional_name)
    return TournamentPlayerStat.none if professional_name.blank?

    TournamentPlayerStat
      .by_professional_name(professional_name)
      .order(year: :desc, computed_at: :desc)
  end

  # Returns the most recent team stat, optionally filtered by league.
  def self.team_stats(team_name, league: nil)
    return nil if team_name.blank?

    scope = TournamentTeamStat
            .where('LOWER(team_name) = LOWER(?)', team_name.strip)
            .order(year: :desc, computed_at: :desc)
    scope = scope.where(league: league) if league.present?
    scope.first
  end
end
