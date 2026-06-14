# frozen_string_literal: true

module MetaIntelligence
  module Controllers
    # Returns Oracle's Elixir split-level stats (teams or players) per tournament.
    #
    # Reads from tournament_team_stats / tournament_player_stats, populated by
    # SyncTournamentStatsJob. All field access goes through model helpers to
    # resolve Datalisk field aliases across versions (gd15 vs GD@15, wr vs WR, etc.).
    #
    # @example Team stats for a tournament
    #   GET /api/v1/meta/split-stats?tournament=CBLOL/2026+Season/Split+1+Playoffs&type=teams
    #
    # @example Player stats filtered by team
    #   GET /api/v1/meta/split-stats?tournament=CBLOL/2026+Season/Split+1+Playoffs&type=players&team=paiN
    #
    # @example Include raw Datalisk payload (debug only)
    #   GET /api/v1/meta/split-stats?tournament=...&type=teams&include_raw=true
    class SplitStatsController < Api::V1::BaseController
      VALID_TYPES = %w[teams players].freeze

      # GET /api/v1/meta/split-stats/tournaments
      def tournaments
        rows = TournamentTeamStat
               .select(:tournament_id, :league, :year)
               .distinct
               .order(year: :desc, league: :asc)
               .map { |r| { tournament_id: r.tournament_id, league: r.league, year: r.year } }

        render_success({ tournaments: rows }, message: 'Available tournaments')
      end

      # GET /api/v1/meta/split-stats
      def index
        tournament = params[:tournament].presence
        return render_error('tournament param is required', status: :unprocessable_entity) unless tournament

        type = params.fetch(:type, 'teams')
        unless VALID_TYPES.include?(type)
          return render_error(
            "type must be one of: #{VALID_TYPES.join(', ')}",
            status: :unprocessable_entity
          )
        end

        include_raw = params[:include_raw] == 'true'
        data        = type == 'teams' ? team_data(tournament, include_raw) : player_data(tournament, include_raw)

        render_success(
          { tournament: tournament, type: type, count: data.size, data: data },
          message: 'Split stats retrieved'
        )
      end

      private

      def team_data(tournament, include_raw)
        TournamentTeamStat.for_tournament(tournament).map do |stat|
          serialize_team(stat, include_raw)
        end
      end

      def player_data(tournament, include_raw)
        scope = TournamentPlayerStat.for_tournament(tournament)
        scope = scope.where('LOWER(team_name) LIKE ?', "%#{params[:team].downcase}%") if params[:team].present?
        scope.map { |stat| serialize_player(stat, include_raw) }
      end

      # All field access via model helpers — never read data['field'] directly.
      def serialize_team(stat, include_raw)
        result = {
          team_name: stat.team_name,
          gp: stat.games_played,
          wr: stat.win_rate,
          gd15: stat.gold_diff_at_15,
          drg_pct: stat.dragon_control_pct,
          wpm: stat.wpm,
          gspd: stat.game_score_diff
        }
        result[:raw] = stat.data if include_raw
        result
      end

      def serialize_player(stat, include_raw)
        result = {
          player_name: stat.player_name,
          team_name: stat.team_name,
          position: stat.position,
          gp: stat.games_played,
          kda: stat.kda,
          deaths: stat.deaths,
          assists: stat.assists,
          dpm: stat.damage_per_minute,
          dmg_pct: stat.damage_share,
          csm: stat.cs_per_minute,
          kp_pct: stat.kill_participation,
          gd15: stat.gold_diff_at_15
        }
        result[:raw] = stat.data if include_raw
        result
      end
    end
  end
end
