# frozen_string_literal: true

module MetaIntelligence
  # Shared serializer helpers for Oracle's Elixir player and team stats.
  module OeStatSerializable
    private

    def serialize_oe_player_stat(stat)
      return nil if stat.nil?

      { tournament_id: stat.tournament_id, league: stat.league, year: stat.year,
        team_name: stat.team_name, position: stat.position,
        gp: stat.games_played, win_rate: stat.win_rate,
        kda: stat.kda, deaths: stat.deaths, assists: stat.assists,
        dpm: stat.damage_per_minute, dmg_pct: stat.damage_share, csm: stat.cs_per_minute,
        kp_pct: stat.kill_participation, gd15: stat.gold_diff_at_15 }
    end

    def serialize_oe_team_stat(stat)
      return nil if stat.nil?

      {
        tournament_id: stat.tournament_id,
        league: stat.league,
        year: stat.year,
        gp: stat.games_played,
        wr: stat.win_rate,
        gd15: stat.gold_diff_at_15,
        drg_pct: stat.dragon_control_pct,
        wpm: stat.wpm,
        gspd: stat.game_score_diff
      }
    end
  end
end
