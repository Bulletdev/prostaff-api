# frozen_string_literal: true

module Api
  module V1
    module Admin
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
        before_action :set_player, only: %i[soft_delete restore enable_access disable_access transfer]

        # GET /api/v1/admin/players
        # Lists all players including soft-deleted ones
        # Admins can see ALL players from ALL organizations
        def index
          if current_user.admin? || current_user.owner?
            # Bypass OrganizationScoped default_scope — admins see all orgs
            base = Player.unscoped
            scope = params[:include_deleted] == 'true' ? base : base.where(deleted_at: nil)
          else
            scope = params[:include_deleted] == 'true' ? Player.with_deleted : Player.all
            scope = scope.where(organization: current_organization)
          end

          players = apply_filters(scope)
          players = apply_sorting(players)

          result = paginate(players)

          # Summary — admins see global counts (bypass default_scope)
          if current_user.admin? || current_user.owner?
            all_players   = Player.unscoped.where(deleted_at: nil)
            deleted_players = Player.unscoped.where.not(deleted_at: nil)
            summary = {
              total:       all_players.count,
              active:      all_players.where(status: 'active').count,
              deleted:     deleted_players.count,
              with_access: all_players.where(player_access_enabled: true).count
            }
          else
            summary_scope = Player.all
            deleted_scope = Player.unscoped.where(organization: current_organization).where.not(deleted_at: nil)
            summary = {
              total:       summary_scope.count,
              active:      summary_scope.where(status: 'active').count,
              deleted:     deleted_scope.count,
              with_access: summary_scope.where(player_access_enabled: true).count
            }
          end

          render_success({
                           players: PlayerSerializer.render_as_hash(result[:data]),
                           pagination: result[:pagination],
                           summary: summary
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

        # POST /api/v1/admin/players/:id/transfer
        # Transfers a player to another organization
        def transfer
          new_organization_id = params[:new_organization_id]
          reason = params[:reason] || 'Player transfer'

          unless new_organization_id.present?
            return render_error(
              message: 'New organization ID is required',
              code: 'VALIDATION_ERROR',
              status: :unprocessable_entity
            )
          end

          new_organization = Organization.find_by(id: new_organization_id)
          unless new_organization
            return render_error(
              message: 'Organization not found',
              code: 'NOT_FOUND',
              status: :not_found
            )
          end

          old_org_id = @player.organization_id

          ActiveRecord::Base.transaction do
            # Save current organization as previous
            @player.update!(previous_organization_id: old_org_id)

            # Transfer to new organization
            @player.update!(organization: new_organization, status: 'inactive')

            log_user_action(
              action: 'transfer',
              entity_type: 'Player',
              entity_id: @player.id,
              old_values: { organization_id: old_org_id },
              new_values: {
                organization_id: new_organization_id,
                previous_organization_id: old_org_id,
                transfer_reason: reason
              }
            )
          end

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

        def require_admin_access
          unless current_user.admin? || current_user.owner?
            render_error(
              message: 'Admin access required',
              code: 'FORBIDDEN',
              status: :forbidden
            )
          end
        end

        def set_player
          # Admin finds players across ALL orgs — must bypass OrganizationScoped default_scope
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
end
