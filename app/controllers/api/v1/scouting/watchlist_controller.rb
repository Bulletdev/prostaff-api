class Api::V1::Scouting::WatchlistController < Api::V1::BaseController
  def index
    # Watchlist is just high-priority scouting targets
    targets = organization_scoped(ScoutingTarget)
              .where(priority: %w[high critical])
              .where(status: %w[watching contacted negotiating])
              .includes(:added_by, :assigned_to)
              .order(priority: :desc, created_at: :desc)

    render_success({
      watchlist: ScoutingTargetSerializer.render_as_hash(targets),
      count: targets.size
    })
  end

  def create
    # Add a scouting target to watchlist by updating its priority
    target = organization_scoped(ScoutingTarget).find(params[:scouting_target_id])

    if target.update(priority: 'high')
      log_user_action(
        action: 'add_to_watchlist',
        entity_type: 'ScoutingTarget',
        entity_id: target.id,
        new_values: { priority: 'high' }
      )

      render_created({
        scouting_target: ScoutingTargetSerializer.render_as_hash(target)
      }, message: 'Added to watchlist')
    else
      render_error(
        message: 'Failed to add to watchlist',
        code: 'UPDATE_ERROR',
        status: :unprocessable_entity
      )
    end
  end

  def destroy
    # Remove from watchlist by lowering priority
    target = organization_scoped(ScoutingTarget).find(params[:id])

    if target.update(priority: 'medium')
      log_user_action(
        action: 'remove_from_watchlist',
        entity_type: 'ScoutingTarget',
        entity_id: target.id,
        new_values: { priority: 'medium' }
      )

      render_deleted(message: 'Removed from watchlist')
    else
      render_error(
        message: 'Failed to remove from watchlist',
        code: 'UPDATE_ERROR',
        status: :unprocessable_entity
      )
    end
  end
end
