# frozen_string_literal: true

module Scouting
  module Controllers
    # Lists OE tournament players absent from any active roster (free agent discovery).
    class FreeAgentsController < Api::V1::BaseController
      include MetaIntelligence::OeStatSerializable

      DISCLAIMER = 'team_name reflects last known tournament, not current contract status'

      OE_SELECT_COLUMNS = 'DISTINCT ON (LOWER(player_name)) ' \
                          'id, player_name, team_name, league, year, position, data, computed_at'

      # GET /api/v1/scouting/oe-free-agents
      #
      # Lists players present in OE tournament data but absent from any active roster.
      # Exactly 3 DB queries regardless of dataset size — no N+1.
      #
      # Params:
      #   league           (string, optional) — e.g. "CBLOL"
      #   year             (integer, optional, default: current year - 1)
      #   position         (string, optional) — e.g. "jng"
      #   exclude_watching (boolean, default: false) — exclude targets already on any watchlist
      def index
        min_year = params[:year] ? params[:year].to_i : (Date.current.year - 1)

        # Query 1: professional names already in an active roster
        known_names = Player
                      .where.not(professional_name: nil)
                      .where(deleted_at: nil)
                      .pluck(Arel.sql('LOWER(professional_name)'))
                      .to_set

        # Query 2: professional names already on the global watchlist
        watching_names = ScoutingTarget
                         .where.not(professional_name: nil)
                         .pluck(Arel.sql('LOWER(professional_name)'))
                         .to_set

        # Query 3: one row per player (most recent by year, computed_at, id) via DISTINCT ON
        candidates = TournamentPlayerStat
                     .where(year: min_year..)
                     .then { |q| params[:league].present?   ? q.where(league: params[:league])     : q }
                     .then { |q| params[:position].present? ? q.where(position: params[:position]) : q }
                     .select(OE_SELECT_COLUMNS)
                     .order(Arel.sql('LOWER(player_name), year DESC, computed_at DESC, id DESC'))

        filtered = candidates.reject { |r| known_names.include?(r.player_name.downcase) }
        if params[:exclude_watching] == 'true'
          filtered = filtered.reject do |r|
            watching_names.include?(r.player_name.downcase)
          end
        end

        result = filtered.map do |r|
          { player_name: r.player_name, team_name: r.team_name, league: r.league,
            year: r.year, position: r.position,
            already_watching: watching_names.include?(r.player_name.downcase),
            stats: serialize_oe_player_stat(r) }
        end

        render_success({ count: result.size, disclaimer: DISCLAIMER, data: result })
      end
    end
  end
end
