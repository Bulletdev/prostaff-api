# frozen_string_literal: true

module Admin
  module Controllers
    # Admin controller for player management
    #
    # Provides administrative operations for managing players including:
    # - Soft delete players who left the team
    # - Restore accidentally deleted players
    # - Enable/disable individual player access
    # - Transfer players between organizations
    # - View all players including deleted ones
    #
    # All operations are logged for audit purposes.
    #
    class PlayersController < Api::V1::BaseController
      before_action :require_admin_access
      before_action :set_player, only: %i[soft_delete restore enable_access disable_access transfer change_status]

      # GET /api/v1/admin/players
      # Lists all players including soft-deleted ones.
      # Super-admins (role=admin) see ALL organizations.
      # Owners see only their own organization.
      def index
        scope  = build_index_scope
        result = paginate(apply_sorting(apply_filters(scope)))

        render_success({
                         players: PlayerSerializer.render_as_hash(result[:data]),
                         pagination: result[:pagination],
                         summary: build_summary
                       })
      end

      # POST /api/v1/admin/players/:id/soft_delete
      # Soft deletes a player with reason
      def soft_delete
        reason = params[:reason] || 'No reason provided'

        if @player.soft_delete!(reason: reason)
          log_user_action(
            action: 'soft_delete',
            entity_type: 'Player',
            entity_id: @player.id,
            old_values: { status: @player.status, deleted_at: nil },
            new_values: { status: 'removed', deleted_at: @player.deleted_at, removed_reason: reason }
          )

          render_success({
                           message: 'Player removed successfully',
                           player: PlayerSerializer.render_as_hash(@player)
                         })
        else
          render_error(
            message: 'Failed to remove player',
            code: 'SOFT_DELETE_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      # POST /api/v1/admin/players/:id/restore
      # Restores a soft-deleted player
      def restore
        new_status = params[:status] || 'inactive'

        unless Constants::Player::STATUSES.include?(new_status)
          return render_error(
            message: "Invalid status: #{new_status}",
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity
          )
        end

        if @player.restore!(new_status: new_status)
          log_user_action(
            action: 'restore',
            entity_type: 'Player',
            entity_id: @player.id,
            old_values: { status: 'removed', deleted_at: @player.deleted_at },
            new_values: { status: new_status, deleted_at: nil }
          )

          render_success({
                           message: 'Player restored successfully',
                           player: PlayerSerializer.render_as_hash(@player)
                         })
        else
          render_error(
            message: 'Failed to restore player',
            code: 'RESTORE_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      # POST /api/v1/admin/players/:id/enable_access
      # Enables individual player access
      def enable_access
        email = params[:email]
        password = params[:password]

        unless email.present? && password.present?
          return render_error(
            message: 'Email and password are required',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity
          )
        end

        if @player.enable_player_access!(email: email, password: password)
          log_user_action(
            action: 'enable_access',
            entity_type: 'Player',
            entity_id: @player.id,
            new_values: { player_email: email, player_access_enabled: true }
          )

          render_success({
                           message: 'Player access enabled successfully',
                           player: PlayerSerializer.render_as_hash(@player)
                         })
        else
          render_error(
            message: 'Failed to enable player access',
            code: 'ENABLE_ACCESS_ERROR',
            status: :unprocessable_entity,
            details: @player.errors.as_json
          )
        end
      end

      # POST /api/v1/admin/players/:id/disable_access
      # Disables individual player access
      def disable_access
        if @player.disable_player_access!
          log_user_action(
            action: 'disable_access',
            entity_type: 'Player',
            entity_id: @player.id,
            old_values: { player_access_enabled: true },
            new_values: { player_access_enabled: false }
          )

          render_success({
                           message: 'Player access disabled successfully',
                           player: PlayerSerializer.render_as_hash(@player)
                         })
        else
          render_error(
            message: 'Failed to disable player access',
            code: 'DISABLE_ACCESS_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      # POST /api/v1/admin/players/:id/change_status
      # Changes the status of a non-deleted player (active / inactive / benched / trial).
      # Use soft_delete to archive a player and restore to un-archive them.
      def change_status
        new_status = params[:status].to_s.strip

        # Disallow setting 'removed' via this endpoint — that is handled by soft_delete
        allowed = Constants::Player::STATUSES - ['removed']
        unless allowed.include?(new_status)
          return render_error(
            message: "Invalid status '#{new_status}'. Allowed: #{allowed.join(', ')}",
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity
          )
        end

        if @player.deleted_at.present?
          return render_error(
            message: 'Cannot change status of an archived player. Use restore instead.',
            code: 'PLAYER_ARCHIVED',
            status: :unprocessable_entity
          )
        end

        old_status = @player.status

        if @player.update(status: new_status)
          log_user_action(
            action: 'change_status',
            entity_type: 'Player',
            entity_id: @player.id,
            old_values: { status: old_status },
            new_values: { status: new_status }
          )

          render_success({
                           message: "Player status changed to #{new_status}",
                           player: PlayerSerializer.render_as_hash(@player)
                         })
        else
          render_error(
            message: 'Failed to update player status',
            code: 'CHANGE_STATUS_ERROR',
            status: :unprocessable_entity,
            details: @player.errors.as_json
          )
        end
      end

      # POST /api/v1/admin/players/:id/transfer
      # Transfers a player to another organization
      def transfer
        new_organization_id = params[:new_organization_id]
        new_organization    = resolve_transfer_target(new_organization_id)
        return unless new_organization

        old_org_id = @player.organization_id
        execute_player_transfer(@player, new_organization, old_org_id, params[:reason])
        publish_player_transferred(@player, old_org_id, new_organization_id)

        render_success({
                         message: 'Player transferred successfully',
                         player: PlayerSerializer.render_as_hash(@player),
                         previous_organization: old_org_id,
                         new_organization: new_organization_id
                       })
      rescue ActiveRecord::RecordInvalid => e
        render_error(
          message: "Failed to transfer player: #{e.message}",
          code: 'TRANSFER_ERROR',
          status: :unprocessable_entity
        )
      end

      private

      def resolve_transfer_target(new_organization_id)
        unless new_organization_id.present?
          render_error(message: 'New organization ID is required', code: 'VALIDATION_ERROR',
                       status: :unprocessable_entity)
          return nil
        end

        org = Organization.find_by(id: new_organization_id)
        render_error(message: 'Organization not found', code: 'NOT_FOUND', status: :not_found) unless org
        org
      end

      def execute_player_transfer(player, new_organization, old_org_id, reason)
        ActiveRecord::Base.transaction do
          player.update!(previous_organization_id: old_org_id)
          player.update!(organization: new_organization, status: 'inactive')
          log_user_action(
            action: 'transfer',
            entity_type: 'Player',
            entity_id: player.id,
            old_values: { organization_id: old_org_id },
            new_values: {
              organization_id: new_organization.id,
              previous_organization_id: old_org_id,
              transfer_reason: reason || 'Player transfer'
            }
          )
        end
      end

      def publish_player_transferred(player, old_org_id, new_organization_id)
        Events::EventPublisher.publish(
          user_id: current_user.id,
          org_id: old_org_id,
          type: 'player.transferred',
          payload: {
            player_id: player.id,
            player_name: player.summoner_name,
            from_org_id: old_org_id,
            to_org_id: new_organization_id
          }
        )
      end

      # Builds the base query scope for the index action.
      #
      # Super-admins (role=admin) bypass multi-tenancy and see every organization.
      # Owners are org-level admins and are scoped to their own organization only.
      #
      # @return [ActiveRecord::Relation]
      def build_index_scope
        if current_user.admin?
          base = Player.unscoped
          params[:include_deleted] == 'true' ? base : base.where(deleted_at: nil)
        else
          base = params[:include_deleted] == 'true' ? Player.with_deleted : Player.all
          base.where(organization: current_organization)
        end
      end

      # Builds summary counts for the index response.
      #
      # Super-admins receive global counts across all organizations.
      # Owners receive counts scoped to their own organization.
      #
      # @return [Hash]
      def build_summary
        if current_user.admin?
          build_global_summary
        else
          build_org_summary
        end
      end

      # @return [Hash]
      def build_global_summary
        all_players     = Player.unscoped.where(deleted_at: nil)
        deleted_players = Player.unscoped.where.not(deleted_at: nil)
        {
          total: all_players.count,
          active: all_players.where(status: 'active').count,
          deleted: deleted_players.count,
          with_access: all_players.where(player_access_enabled: true).count
        }
      end

      # @return [Hash]
      def build_org_summary
        base         = Player.all
        deleted_base = Player.unscoped.where(organization: current_organization).where.not(deleted_at: nil)
        {
          total: base.count,
          active: base.where(status: 'active').count,
          deleted: deleted_base.count,
          with_access: base.where(player_access_enabled: true).count
        }
      end

      def require_admin_access
        return if current_user.admin? || current_user.owner?

        render_error(
          message: 'Admin access required',
          code: 'FORBIDDEN',
          status: :forbidden
        )
      end

      def set_player
        # Admin finds players across ALL orgs — must bypass OrganizationScoped default_scope.
        # Access control is enforced by require_admin_access before_action on every action
        # that calls set_player. Unscoped is intentional and safe in this admin context.
        # nosemgrep: ruby.rails.security.brakeman.check-unscoped-find.check-unscoped-find
        @player = Player.unscoped.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error(
          message: 'Player not found',
          code: 'NOT_FOUND',
          status: :not_found
        )
      end

      def apply_filters(players)
        players = players.by_role(params[:role]) if params[:role].present?
        players = players.by_status(params[:status]) if params[:status].present?
        players = players.with_player_access if params[:has_access] == 'true'
        players
      end

      def apply_sorting(players)
        sort_by = params[:sort_by] || 'created_at'
        sort_order = params[:sort_order] || 'desc'

        allowed_fields = %w[summoner_name real_name role status created_at deleted_at]
        sort_by = 'created_at' unless allowed_fields.include?(sort_by)

        players.order(sort_by => sort_order)
      end
    end
  end
end
