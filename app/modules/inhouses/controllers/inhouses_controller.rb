# frozen_string_literal: true

module Inhouses
  module Controllers
    # InhousesController
    #
    # Manages internal practice sessions (inhouses) where an organization's
    # own players compete against each other in balanced teams.
    #
    # Lifecycle: waiting → in_progress (after balance_teams) → done (after close)
    #
    # Endpoints:
    #   GET    /api/v1/inhouse/inhouses            — paginated history (done sessions)
    #   GET    /api/v1/inhouse/inhouses/active      — current active session
    #   POST   /api/v1/inhouse/inhouses             — create new session
    #   POST   /api/v1/inhouse/inhouses/:id/join    — add a player to the lobby
    #   POST   /api/v1/inhouse/inhouses/:id/balance_teams — auto-assign teams
    #   POST   /api/v1/inhouse/inhouses/:id/record_game   — record game result
    #   PATCH  /api/v1/inhouse/inhouses/:id/close   — close the session
    #
    class InhousesController < Api::V1::BaseController
      before_action :set_inhouse, only: %i[join balance_teams start_draft captain_pick start_game record_game close]

      # GET /api/v1/inhouse/ladder
      # Returns per-player win/loss/win-rate aggregated across all done sessions.
      def ladder
        authorize Inhouse

        rows = InhouseParticipation
               .joins(:inhouse, :player)
               .where(inhouses: { organization_id: current_organization.id, status: 'done' })
               .where.not(team: 'none')
               .group(:player_id)
               .select(
                 'player_id',
                 'SUM(wins) AS total_wins',
                 'SUM(losses) AS total_losses'
               )
               .to_a

        player_ids = rows.map(&:player_id)
        players_by_id = current_organization.players
                                            .where(id: player_ids)
                                            .index_by(&:id)

        entries = rows.map do |row|
          player = players_by_id[row.player_id]
          next unless player

          total = row.total_wins.to_i + row.total_losses.to_i
          win_rate = total.zero? ? 0.0 : (row.total_wins.to_f / total * 100).round(1)

          {
            player_id: row.player_id,
            player_name: player.summoner_name,
            role: player.role,
            wins: row.total_wins.to_i,
            losses: row.total_losses.to_i,
            total_games: total,
            win_rate: win_rate
          }
        end.compact

        entries.sort_by! { |e| [-e[:wins], e[:losses]] }
        entries.each_with_index { |e, i| e[:rank] = i + 1 }

        render_success({ entries: entries, total: entries.size })
      end

      # GET /api/v1/inhouse/sessions
      # Returns paginated history of completed inhouse sessions with summary.
      def sessions
        authorize Inhouse

        inhouses = current_organization.inhouses.history.recent
                                       .includes(:inhouse_participations)

        page     = (params[:page] || 1).to_i
        per_page = [(params[:per_page] || 10).to_i, 50].min
        inhouses = inhouses.page(page).per(per_page)

        sessions = inhouses.map do |ih|
          {
            id: ih.id,
            games_played: ih.games_played,
            blue_wins: ih.blue_wins,
            red_wins: ih.red_wins,
            player_count: ih.inhouse_participations.size,
            formation_mode: ih.formation_mode,
            created_at: ih.created_at,
            closed_at: ih.updated_at
          }
        end

        render_success({
                         sessions: sessions,
                         meta: {
                           current_page: inhouses.current_page,
                           total_pages: inhouses.total_pages,
                           total_count: inhouses.total_count
                         }
                       })
      end

      # GET /api/v1/inhouse/inhouses
      # Returns paginated history of completed inhouse sessions.
      # Pass ?all=true to include active ones too.
      def index
        authorize Inhouse

        inhouses = if params[:all].present?
                     current_organization.inhouses
                   else
                     current_organization.inhouses.history
                   end

        inhouses = inhouses.recent.includes(:inhouse_participations)

        page     = (params[:page] || 1).to_i
        per_page = [(params[:per_page] || 20).to_i, 100].min
        inhouses = inhouses.page(page).per(per_page)

        render_success(
          inhouses: inhouses.map { |i| serialize_inhouse(i) },
          meta: {
            current_page: inhouses.current_page,
            total_pages: inhouses.total_pages,
            total_count: inhouses.total_count
          }
        )
      end

      # GET /api/v1/inhouse/inhouses/active
      # Returns the current active inhouse (waiting or in_progress), if any.
      def active
        authorize Inhouse

        inhouse = current_organization.inhouses
                                      .active
                                      .includes(inhouse_participations: :player)
                                      .order(created_at: :desc)
                                      .first

        return render_success({ inhouse: nil }) if inhouse.nil?

        render_success({ inhouse: serialize_inhouse(inhouse, detailed: true) })
      end

      # POST /api/v1/inhouse/inhouses
      # Creates a new inhouse session. Fails if an active one already exists.
      def create
        authorize Inhouse

        if current_organization.inhouses.active.exists?
          return render_error(
            message: 'There is already an active inhouse session for this organization',
            code: 'ACTIVE_INHOUSE_EXISTS',
            status: :unprocessable_entity
          )
        end

        inhouse = current_organization.inhouses.new(
          status: 'waiting',
          created_by: current_user
        )

        if inhouse.save
          render_created({ inhouse: serialize_inhouse(inhouse, detailed: true) },
                         message: 'Inhouse session created')
        else
          render_error(
            message: 'Failed to create inhouse session',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: inhouse.errors.as_json
          )
        end
      end

      # POST /api/v1/inhouse/inhouses/:id/join
      # Adds a player to the inhouse lobby.
      # Body: { player_id: <uuid> }
      def join
        authorize @inhouse

        unless @inhouse.waiting?
          return render_error(
            message: 'Can only join a session that is waiting for players',
            code: 'INVALID_STATE',
            status: :unprocessable_entity
          )
        end

        player = current_organization.players.find_by(id: params[:player_id])
        unless player
          return render_error(
            message: 'Player not found in this organization',
            code: 'PLAYER_NOT_FOUND',
            status: :not_found
          )
        end

        if @inhouse.inhouse_participations.exists?(player_id: player.id)
          return render_error(
            message: 'Player is already in this inhouse session',
            code: 'ALREADY_JOINED',
            status: :unprocessable_entity
          )
        end

        participation = @inhouse.inhouse_participations.new(
          player: player,
          team: 'none',
          tier_snapshot: player.solo_queue_tier.presence
        )

        if participation.save
          render_success(
            { inhouse: serialize_inhouse(@inhouse.reload, detailed: true) },
            message: "#{player.summoner_name} joined the inhouse"
          )
        else
          render_error(
            message: 'Failed to add player to inhouse',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: participation.errors.as_json
          )
        end
      end

      # POST /api/v1/inhouse/inhouses/:id/balance_teams
      # Auto-assigns teams using a snake draft sorted by LoL tier score.
      # Works from both waiting and in_progress (allows reshuffling mid-session).
      def balance_teams
        authorize @inhouse

        if @inhouse.done?
          return render_error(
            message: 'Cannot rebalance a closed session',
            code: 'INVALID_STATE',
            status: :unprocessable_entity
          )
        end

        participations = @inhouse.inhouse_participations.includes(:player).to_a

        if participations.size < 2
          return render_error(
            message: 'Need at least 2 players to balance teams',
            code: 'NOT_ENOUGH_PLAYERS',
            status: :unprocessable_entity
          )
        end

        apply_snake_draft(participations)

        attrs = { formation_mode: 'auto' }
        attrs[:status] = 'in_progress' if @inhouse.waiting? || @inhouse.draft?
        @inhouse.update!(attrs)

        render_success(
          { inhouse: serialize_inhouse(@inhouse.reload, detailed: true) },
          message: 'Teams balanced'
        )
      end

      # POST /api/v1/inhouse/inhouses/:id/start_draft
      # Begins the captain draft phase. Assigns blue and red captains,
      # transitions status to 'draft', and initialises pick_number to 0.
      # Body: { blue_captain_id: <uuid>, red_captain_id: <uuid> }
      def start_draft
        authorize @inhouse

        unless @inhouse.waiting?
          return render_error(
            message: 'Can only start draft from a waiting session',
            code: 'INVALID_STATE',
            status: :unprocessable_entity
          )
        end

        blue_id = params[:blue_captain_id].to_s
        red_id  = params[:red_captain_id].to_s

        if blue_id.blank? || red_id.blank?
          return render_error(
            message: 'blue_captain_id and red_captain_id are required',
            code: 'MISSING_PARAMS',
            status: :unprocessable_entity
          )
        end

        if blue_id == red_id
          return render_error(
            message: 'Blue and red captains must be different players',
            code: 'DUPLICATE_CAPTAIN',
            status: :unprocessable_entity
          )
        end

        blue_participation = @inhouse.inhouse_participations.find_by(player_id: blue_id)
        red_participation  = @inhouse.inhouse_participations.find_by(player_id: red_id)

        unless blue_participation && red_participation
          return render_error(
            message: 'Both captains must already be in the session',
            code: 'CAPTAIN_NOT_IN_SESSION',
            status: :unprocessable_entity
          )
        end

        ActiveRecord::Base.transaction do
          # Mark captains and assign teams
          blue_participation.update!(team: 'blue', is_captain: true)
          red_participation.update!(team: 'red', is_captain: true)

          # All other players reset to 'none' (unassigned) so draft picks them
          @inhouse.inhouse_participations
                  .where.not(player_id: [blue_id, red_id])
                  .update_all(team: 'none', is_captain: false)

          @inhouse.update!(
            status: 'draft',
            formation_mode: 'captain_draft',
            blue_captain_id: blue_id,
            red_captain_id: red_id,
            draft_pick_number: 0
          )
        end

        render_success(
          { inhouse: serialize_inhouse(@inhouse.reload, detailed: true) },
          message: 'Captain draft started'
        )
      end

      # POST /api/v1/inhouse/inhouses/:id/captain_pick
      # The current team's captain picks a player from the unpicked pool.
      # Body: { player_id: <uuid> }
      def captain_pick
        authorize @inhouse

        unless @inhouse.draft?
          return render_error(
            message: 'Captain picks can only be made during the draft phase',
            code: 'INVALID_STATE',
            status: :unprocessable_entity
          )
        end

        if @inhouse.draft_complete?
          return render_error(
            message: 'All picks have already been made',
            code: 'DRAFT_COMPLETE',
            status: :unprocessable_entity
          )
        end

        player_id = params[:player_id].to_s
        if player_id.blank?
          return render_error(
            message: 'player_id is required',
            code: 'MISSING_PARAMS',
            status: :unprocessable_entity
          )
        end

        participation = @inhouse.inhouse_participations.find_by(player_id: player_id)
        unless participation
          return render_error(
            message: 'Player is not in this inhouse session',
            code: 'PLAYER_NOT_IN_SESSION',
            status: :not_found
          )
        end

        if participation.is_captain?
          return render_error(
            message: 'Captains cannot be picked — they are already on their teams',
            code: 'PLAYER_IS_CAPTAIN',
            status: :unprocessable_entity
          )
        end

        if participation.team != 'none'
          return render_error(
            message: 'Player has already been picked',
            code: 'ALREADY_PICKED',
            status: :unprocessable_entity
          )
        end

        picking_team = @inhouse.current_pick_team

        ActiveRecord::Base.transaction do
          participation.update!(team: picking_team)
          @inhouse.increment!(:draft_pick_number)
        end

        render_success(
          { inhouse: serialize_inhouse(@inhouse.reload, detailed: true) },
          message: "#{picking_team.capitalize} team picked a player"
        )
      end

      # POST /api/v1/inhouse/inhouses/:id/start_game
      # Transitions from draft to in_progress, locking the teams.
      # Can be called once the draft is complete or by the coach to force-start.
      def start_game
        authorize @inhouse

        unless @inhouse.draft?
          return render_error(
            message: 'Session must be in draft phase to start the game',
            code: 'INVALID_STATE',
            status: :unprocessable_entity
          )
        end

        @inhouse.update!(status: 'in_progress')

        render_success(
          { inhouse: serialize_inhouse(@inhouse.reload, detailed: true) },
          message: 'Game started — teams locked'
        )
      end

      # POST /api/v1/inhouse/inhouses/:id/record_game
      # Records a game result. Body: { winner: 'blue'|'red' }
      def record_game
        authorize @inhouse

        unless @inhouse.in_progress?
          return render_error(
            message: 'Can only record games for a session that is in progress',
            code: 'INVALID_STATE',
            status: :unprocessable_entity
          )
        end

        winner = params[:winner].to_s
        unless %w[blue red].include?(winner)
          return render_error(
            message: "winner must be 'blue' or 'red'",
            code: 'INVALID_WINNER',
            status: :unprocessable_entity
          )
        end

        @inhouse.increment!(:games_played)
        if winner == 'blue'
          @inhouse.increment!(:blue_wins)
        else
          @inhouse.increment!(:red_wins)
        end

        # Update per-player wins/losses
        @inhouse.inhouse_participations.each do |p|
          next if p.team == 'none'

          if p.team == winner
            p.increment!(:wins)
          else
            p.increment!(:losses)
          end
        end

        render_success(
          { inhouse: serialize_inhouse(@inhouse.reload) },
          message: "Game recorded — #{winner.capitalize} team wins"
        )
      end

      # PATCH /api/v1/inhouse/inhouses/:id/close
      # Closes the inhouse session (sets status to done).
      def close
        authorize @inhouse

        if @inhouse.done?
          return render_error(
            message: 'Session is already closed',
            code: 'ALREADY_CLOSED',
            status: :unprocessable_entity
          )
        end

        if @inhouse.update(status: 'done')
          render_success(
            { inhouse: serialize_inhouse(@inhouse.reload) },
            message: 'Inhouse session closed'
          )
        else
          render_error(
            message: 'Failed to close inhouse session',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: @inhouse.errors.as_json
          )
        end
      end

      private

      # Snake draft: sort by tier desc, alternate teams pair by pair.
      # Pair 0 → [B,R], pair 1 → [R,B], pair 2 → [B,R], ...
      def apply_snake_draft(participations)
        sorted = participations.sort_by { |p| -tier_score(p.tier_snapshot) }
        sorted.each_with_index do |participation, index|
          pair = index / 2
          pos  = index % 2
          team = if pair.even?
                   pos.zero? ? 'blue' : 'red'
                 else
                   (pos.zero? ? 'red' : 'blue')
                 end
          participation.update_columns(team: team)
        end
      end

      def set_inhouse
        @inhouse = current_organization.inhouses.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      # Returns a tier score (0–9) for snake draft balancing.
      # Uses LoL solo queue tiers. Higher = stronger player.
      def tier_score(tier_snapshot)
        case tier_snapshot.to_s.upcase
        when 'CHALLENGER'   then 9
        when 'GRANDMASTER'  then 8
        when 'MASTER'       then 7
        when 'DIAMOND'      then 6
        when 'EMERALD'      then 5
        when 'PLATINUM'     then 4
        when 'GOLD'         then 3
        when 'SILVER'       then 2
        when 'BRONZE'       then 1
        else                     0 # IRON or unknown
        end
      end

      # Serializes an inhouse to a hash.
      # Pass detailed: true to include full participation list and draft state.
      def serialize_inhouse(inhouse, detailed: false)
        result = {
          id: inhouse.id,
          status: inhouse.status,
          formation_mode: inhouse.formation_mode,
          games_played: inhouse.games_played,
          blue_wins: inhouse.blue_wins,
          red_wins: inhouse.red_wins,
          created_at: inhouse.created_at,
          updated_at: inhouse.updated_at
        }

        if inhouse.draft? || (detailed && inhouse.blue_captain_id.present?)
          result[:draft_state] = {
            blue_captain_id: inhouse.blue_captain_id,
            red_captain_id: inhouse.red_captain_id,
            pick_number: inhouse.draft_pick_number.to_i,
            current_pick_team: inhouse.current_pick_team,
            picks_remaining: [Inhouse::PICK_ORDER.size - inhouse.draft_pick_number.to_i, 0].max,
            draft_complete: inhouse.draft_complete?
          }
        end

        if detailed
          participations = inhouse.inhouse_participations.includes(:player)
          result[:participations] = participations.map do |p|
            {
              id: p.id,
              player_id: p.player_id,
              player_name: p.player&.summoner_name,
              team: p.team,
              tier_snapshot: p.tier_snapshot,
              is_captain: p.is_captain,
              wins: p.wins,
              losses: p.losses
            }
          end
        end

        result
      end
    end
  end
end
