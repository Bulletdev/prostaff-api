# frozen_string_literal: true

module Inhouses
  module Controllers
    # InhouseQueuesController
    #
    # Manages the server-side queue for inhouse sessions.
    # Both the web dashboard and Discord bot interact with this queue.
    #
    # Lifecycle: open → check_in → closed (after start_session or manual close)
    #
    # Endpoints:
    #   GET    /api/v1/inhouse/queue/status        — active queue or null
    #   POST   /api/v1/inhouse/queue/open          — create a new queue [coach]
    #   POST   /api/v1/inhouse/queue/join          — add player to queue by role
    #   POST   /api/v1/inhouse/queue/leave         — remove player from queue
    #   POST   /api/v1/inhouse/queue/start_checkin — begin check-in phase [coach]
    #   POST   /api/v1/inhouse/queue/checkin       — mark player as checked in
    #   POST   /api/v1/inhouse/queue/start_session — create inhouse from queue [coach]
    #   POST   /api/v1/inhouse/queue/close         — discard queue [coach]
    #
    class InhouseQueuesController < Api::V1::BaseController
      CHECK_IN_DURATION_SECONDS = 90

      # GET /api/v1/inhouse/queue/status
      def status
        authorize InhouseQueue

        queue = current_organization.inhouse_queues.active.includes(inhouse_queue_entries: :player).first
        return render_success({ queue: nil }) if queue.nil?

        render_success({ queue: queue.serialize(detailed: true) })
      end

      # POST /api/v1/inhouse/queue/open
      def open
        authorize InhouseQueue

        if current_organization.inhouse_queues.active.exists?
          return render_error(
            message: 'There is already an active queue for this organization',
            code: 'ACTIVE_QUEUE_EXISTS',
            status: :unprocessable_entity
          )
        end

        queue = current_organization.inhouse_queues.new(
          status: 'open',
          created_by: current_user
        )

        if queue.save
          render_created({ queue: queue.serialize(detailed: true) }, message: 'Queue opened')
        else
          render_error(message: 'Failed to open queue', code: 'VALIDATION_ERROR',
                       status: :unprocessable_entity, details: queue.errors.as_json)
        end
      end

      # POST /api/v1/inhouse/queue/join
      # Body: { player_id, role }
      def join
        authorize InhouseQueue

        queue = active_queue
        return unless queue

        error = validate_join(queue, params[:role].to_s.downcase, params[:player_id].to_s)
        return render_error(**error) if error

        role   = params[:role].to_s.downcase
        player = current_organization.players.find(params[:player_id])
        entry  = queue.inhouse_queue_entries.new(
          player: player,
          role: role,
          tier_snapshot: player.solo_queue_tier.presence || 'IRON'
        )

        if entry.save
          render_success({ queue: queue.reload.serialize(detailed: true) },
                         message: "#{player.summoner_name} joined the queue as #{role}")
        else
          render_error(message: 'Failed to join queue', code: 'VALIDATION_ERROR',
                       status: :unprocessable_entity, details: entry.errors.as_json)
        end
      end

      # POST /api/v1/inhouse/queue/leave
      # Body: { player_id }
      def leave
        authorize InhouseQueue

        queue = active_queue
        return unless queue

        player_id = params[:player_id].to_s
        entry = queue.inhouse_queue_entries.find_by(player_id: player_id)

        unless entry
          return render_error(message: 'Player is not in the queue', code: 'NOT_IN_QUEUE', status: :not_found)
        end

        entry.destroy!
        queue.reload
        render_success({ queue: queue.serialize(detailed: true) }, message: 'Player removed from queue')
      end

      # POST /api/v1/inhouse/queue/start_checkin
      def start_checkin
        authorize InhouseQueue

        queue = active_queue
        return unless queue

        unless queue.open?
          return render_error(message: 'Queue is not in open state', code: 'INVALID_STATE',
                              status: :unprocessable_entity)
        end

        if queue.inhouse_queue_entries.size < 2
          return render_error(message: 'Need at least 2 players to start check-in',
                              code: 'NOT_ENOUGH_PLAYERS', status: :unprocessable_entity)
        end

        deadline = Time.current + CHECK_IN_DURATION_SECONDS.seconds
        queue.update!(status: 'check_in', check_in_deadline: deadline)

        render_success({ queue: queue.reload.serialize(detailed: true) }, message: 'Check-in started')
      end

      # POST /api/v1/inhouse/queue/checkin
      # Body: { player_id }
      def checkin
        authorize InhouseQueue

        queue = active_queue
        return unless queue

        unless queue.check_in?
          return render_error(message: 'Check-in phase is not active', code: 'INVALID_STATE',
                              status: :unprocessable_entity)
        end

        player_id = params[:player_id].to_s
        entry = queue.inhouse_queue_entries.find_by(player_id: player_id)

        unless entry
          return render_error(message: 'Player is not in the queue', code: 'NOT_IN_QUEUE', status: :not_found)
        end

        entry.update!(checked_in: true, checked_in_at: Time.current)
        queue.reload

        render_success({ queue: queue.serialize(detailed: true) },
                       message: "#{entry.player&.summoner_name} checked in")
      end

      # POST /api/v1/inhouse/queue/start_session
      # Body: { formation_mode: 'auto' | 'captain_draft' }
      def start_session
        authorize InhouseQueue

        queue = active_queue
        return unless queue

        formation_mode = params[:formation_mode].to_s
        return render_invalid_formation_mode unless %w[auto captain_draft].include?(formation_mode)

        entries = queue.checked_in_entries.includes(:player).to_a
        return render_not_enough_players if entries.size < 2
        return render_active_inhouse_exists if current_organization.inhouses.active.exists?

        inhouse = create_inhouse_from_queue!(queue, entries, formation_mode)

        render_success(
          { inhouse: serialize_inhouse(inhouse.reload, detailed: true) },
          message: 'Inhouse session started from queue'
        )
      rescue ActiveRecord::RecordInvalid => e
        render_error(message: e.message, code: 'VALIDATION_ERROR', status: :unprocessable_entity)
      end

      # POST /api/v1/inhouse/queue/close
      def close
        authorize InhouseQueue

        queue = active_queue
        return unless queue

        queue.update!(status: 'closed')
        render_success({ queue: nil }, message: 'Queue closed')
      end

      private

      # Returns an error hash if the join cannot proceed, nil if valid.
      def validate_join(queue, role, player_id)
        unless queue.open?
          return { message: 'Queue is not accepting new players right now', code: 'QUEUE_NOT_OPEN',
                   status: :unprocessable_entity }
        end
        unless InhouseQueue::ROLES.include?(role)
          return { message: "role must be one of: #{InhouseQueue::ROLES.join(', ')}", code: 'INVALID_ROLE',
                   status: :unprocessable_entity }
        end

        player = current_organization.players.find_by(id: player_id)
        unless player
          return { message: 'Player not found in this organization', code: 'PLAYER_NOT_FOUND',
                   status: :not_found }
        end
        if queue.inhouse_queue_entries.exists?(player_id: player.id)
          return { message: 'Player is already in the queue', code: 'ALREADY_IN_QUEUE',
                   status: :unprocessable_entity }
        end
        if queue.slots_for_role(role) >= 2
          return { message: "Role '#{role}' is already full (2/2)", code: 'ROLE_FULL',
                   status: :unprocessable_entity }
        end
        return { message: 'Queue is full (10/10)', code: 'QUEUE_FULL', status: :unprocessable_entity } if queue.full?

        nil
      end

      def render_invalid_formation_mode
        render_error(
          message: "formation_mode must be 'auto' or 'captain_draft'",
          code: 'INVALID_FORMATION_MODE',
          status: :unprocessable_entity
        )
      end

      def render_not_enough_players
        render_error(
          message: 'Need at least 2 checked-in players to start a session',
          code: 'NOT_ENOUGH_PLAYERS',
          status: :unprocessable_entity
        )
      end

      def render_active_inhouse_exists
        render_error(
          message: 'There is already an active inhouse session',
          code: 'ACTIVE_INHOUSE_EXISTS',
          status: :unprocessable_entity
        )
      end

      def create_inhouse_from_queue!(queue, entries, formation_mode)
        inhouse = nil
        ActiveRecord::Base.transaction do
          inhouse = current_organization.inhouses.create!(
            status: 'waiting',
            created_by: current_user,
            formation_mode: formation_mode
          )
          entries.each do |entry|
            inhouse.inhouse_participations.create!(
              player: entry.player,
              team: 'none',
              tier_snapshot: entry.tier_snapshot,
              role: entry.role,
              is_captain: false
            )
          end
          if formation_mode == 'auto'
            apply_auto_balance(inhouse)
          else
            apply_captain_draft(inhouse, entries)
          end
          queue.update!(status: 'closed')
        end
        inhouse
      end

      def active_queue
        queue = current_organization.inhouse_queues.active.includes(inhouse_queue_entries: :player).first
        unless queue
          render_error(message: 'No active queue found', code: 'NO_ACTIVE_QUEUE', status: :not_found)
          return nil
        end
        queue
      end

      # Auto-balance: snake draft sorted by tier descending
      def apply_auto_balance(inhouse)
        participations = inhouse.inhouse_participations.includes(:player).to_a
        sorted = participations.sort_by { |p| -tier_score(p.tier_snapshot) }

        sorted.each_with_index do |participation, index|
          pair             = index / 2
          position_in_pair = index % 2
          team = if pair.even?
                   position_in_pair.zero? ? 'blue' : 'red'
                 else
                   position_in_pair.zero? ? 'red' : 'blue'
                 end
          participation.update_columns(team: team)
        end

        inhouse.update!(status: 'in_progress')
      end

      # Captain draft: select captains from the most balanced role (lowest std dev),
      # then transition to draft phase.
      def apply_captain_draft(inhouse, entries)
        suggestion = select_captains_by_stddev(entries)

        unless suggestion
          # Fallback to closest-to-mean if no role has a pair
          pts  = entries.map { |e| tier_to_points(e.tier_snapshot) }
          mean = pts.sum.to_f / pts.size
          sorted_by_mean = entries.sort_by { |e| (tier_to_points(e.tier_snapshot) - mean).abs }
          blue_id = sorted_by_mean[0]&.player_id
          red_id  = sorted_by_mean[1]&.player_id

          suggestion = { blue_id: blue_id, red_id: red_id }
        end

        blue_p = inhouse.inhouse_participations.find_by!(player_id: suggestion[:blue_id])
        red_p  = inhouse.inhouse_participations.find_by!(player_id: suggestion[:red_id])

        blue_p.update!(team: 'blue', is_captain: true)
        red_p.update!(team: 'red',   is_captain: true)

        inhouse.update!(
          status: 'draft',
          blue_captain_id: suggestion[:blue_id],
          red_captain_id: suggestion[:red_id],
          draft_pick_number: 0
        )
      end

      # Finds the role pair with the lowest std dev in tier points —
      # this is the most evenly matched pair to serve as captains.
      def select_captains_by_stddev(entries)
        by_role = entries.group_by(&:role).select { |_, players| players.size == 2 }
        return nil if by_role.empty?

        best_role, best_players = by_role.min_by do |_, players|
          pts = players.map { |e| tier_to_points(e.tier_snapshot) }
          std_dev(pts)
        end

        return nil unless best_role

        sorted = best_players.sort_by { |e| -tier_to_points(e.tier_snapshot) }
        { blue_id: sorted[0].player_id, red_id: sorted[1].player_id }
      end

      def std_dev(values)
        return 0 if values.size < 2

        mean = values.sum.to_f / values.size
        Math.sqrt(values.sum { |v| (v - mean)**2 } / values.size)
      end

      def tier_to_points(tier)
        {
          'tier_1_professional' => 1800, 'professional' => 1800,
          'tier_2_semi_pro' => 1200, 'semi_pro' => 1200,
          'tier_3_amateur' => 800, 'amateur' => 800,
          'CHALLENGER' => 2800, 'GRANDMASTER' => 2600, 'MASTER' => 2400,
          'DIAMOND' => 2000, 'EMERALD' => 1800, 'PLATINUM' => 1600,
          'GOLD' => 1400, 'SILVER' => 1200, 'BRONZE' => 1000, 'IRON' => 800
        }.fetch(tier.to_s.upcase, 1000)
      end

      TIER_SCORES = {
        'CHALLENGER' => 9, 'GRANDMASTER' => 8, 'MASTER' => 7,
        'DIAMOND' => 6, 'EMERALD' => 5, 'PLATINUM' => 4,
        'GOLD' => 3, 'SILVER' => 2, 'BRONZE' => 1
      }.freeze

      def tier_score(tier_snapshot)
        TIER_SCORES.fetch(tier_snapshot.to_s.upcase, 0)
      end

      # Reuse serializer from InhousesController via delegation
      def serialize_inhouse(inhouse, detailed: false)
        result = {
          id: inhouse.id,
          status: inhouse.status,
          formation_mode: inhouse.formation_mode,
          games_played: inhouse.games_played,
          blue_wins: inhouse.blue_wins,
          red_wins: inhouse.red_wins,
          created_at: inhouse.created_at
        }

        if inhouse.draft?
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
              role: p.role,
              tier_snapshot: p.tier_snapshot,
              mu_snapshot: p.mu_snapshot,
              sigma_snapshot: p.sigma_snapshot,
              mmr_delta: p.mmr_delta,
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
