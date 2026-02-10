# frozen_string_literal: true

module Api
  module V1
    # Controller for managing player roster operations
    # Handles removing players from roster, hiring from scouting pool, and free agent management
    class RostersController < BaseController
      before_action :set_player, only: [:remove_from_roster]
      before_action :set_scouting_target, only: [:hire_from_scouting]

      # POST /api/v1/roster/remove/:player_id
      # Remove a player from the current roster
      def remove_from_roster
        reason = params[:reason] || 'Released from team'

        service = Players::RosterManagementService.new(
          player: @player,
          organization: current_organization,
          current_user: current_user
        )

        result = service.remove_from_roster(reason: reason)

        if result[:success]
          log_user_action(
            action: 'roster_removal',
            entity_type: 'Player',
            entity_id: @player.id,
            old_values: { status: 'active' },
            new_values: { status: 'removed', reason: reason }
          )

          render_success({
            player: PlayerSerializer.render_as_hash(@player),
            scouting_target: ScoutingTargetSerializer.render_as_hash(result[:scouting_target]),
            message: result[:message]
          })
        else
          render_error(
            message: result[:error],
            code: result[:code],
            status: :unprocessable_entity
          )
        end
      end

      # POST /api/v1/roster/hire/:scouting_target_id
      # Hire a player from the scouting pool
      def hire_from_scouting
        contract_params = validate_contract_params
        return unless contract_params

        result = Players::RosterManagementService.hire_from_scouting(
          scouting_target: @scouting_target,
          organization: current_organization,
          contract_start: contract_params[:contract_start],
          contract_end: contract_params[:contract_end],
          salary: contract_params[:salary],
          jersey_number: contract_params[:jersey_number],
          current_user: current_user
        )

        if result[:success]
          render_created({
            player: PlayerSerializer.render_as_hash(result[:player]),
            message: result[:message]
          })
        else
          render_error(
            message: result[:error],
            code: result[:code],
            status: :unprocessable_entity
          )
        end
      end

      # GET /api/v1/roster/free_agents
      # List all free agents (players without teams)
      def free_agents
        players = Players::RosterManagementService.free_agents

        # Apply filters
        players = players.by_role(params[:role]) if params[:role].present?
        players = players.by_tier(params[:tier]) if params[:tier].present?

        if params[:search].present?
          search_term = "%#{params[:search]}%"
          players = players.where('summoner_name ILIKE ? OR real_name ILIKE ?', search_term, search_term)
        end

        result = paginate(players)

        free_agents_data = result[:data].map do |player|
          {
            player: PlayerSerializer.render_as_hash(player),
            previous_organization: player.previous_organization_id ?
              Organization.find(player.previous_organization_id).name : nil,
            removed_at: player.deleted_at,
            removed_reason: player.removed_reason
          }
        end

        render_success({
          free_agents: free_agents_data,
          pagination: result[:pagination]
        })
      end

      # GET /api/v1/roster/statistics
      # Get roster statistics (active players, free agents, etc.)
      def statistics
        active_players = organization_scoped(Player).active.count
        inactive_players = organization_scoped(Player).where(status: 'inactive').count
        benched_players = organization_scoped(Player).where(status: 'benched').count
        removed_players = Player.with_deleted
                                .where(organization_id: current_organization.id, status: 'removed')
                                .count

        # Roster composition by role
        roster_by_role = organization_scoped(Player).active.group(:role).count

        # Contract expiring soon
        contracts_expiring = organization_scoped(Player)
                              .active
                              .contracts_expiring_soon(30)
                              .count

        render_success({
          roster_count: active_players,
          inactive_count: inactive_players,
          benched_count: benched_players,
          removed_count: removed_players,
          roster_by_role: roster_by_role,
          contracts_expiring_soon: contracts_expiring
        })
      end

      private

      def set_player
        @player = organization_scoped(Player).find(params[:player_id])
      rescue ActiveRecord::RecordNotFound
        render_error(
          message: 'Player not found in your organization',
          code: 'PLAYER_NOT_FOUND',
          status: :not_found
        )
      end

      def set_scouting_target
        @scouting_target = organization_scoped(ScoutingTarget).find(params[:scouting_target_id])
      rescue ActiveRecord::RecordNotFound
        render_error(
          message: 'Scouting target not found',
          code: 'SCOUTING_TARGET_NOT_FOUND',
          status: :not_found
        )
      end

      def validate_contract_params
        contract_start = params[:contract_start]
        contract_end = params[:contract_end]

        unless contract_start.present? && contract_end.present?
          render_error(
            message: 'Contract start and end dates are required',
            code: 'MISSING_CONTRACT_DATES',
            status: :unprocessable_entity
          )
          return nil
        end

        begin
          contract_start_date = Date.parse(contract_start)
          contract_end_date = Date.parse(contract_end)

          if contract_end_date <= contract_start_date
            render_error(
              message: 'Contract end date must be after start date',
              code: 'INVALID_CONTRACT_DATES',
              status: :unprocessable_entity
            )
            return nil
          end

          {
            contract_start: contract_start_date,
            contract_end: contract_end_date,
            salary: params[:salary]&.to_d,
            jersey_number: params[:jersey_number]&.to_i
          }
        rescue ArgumentError
          render_error(
            message: 'Invalid date format. Use YYYY-MM-DD',
            code: 'INVALID_DATE_FORMAT',
            status: :unprocessable_entity
          )
          nil
        end
      end
    end
  end
end
