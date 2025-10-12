class Api::V1::RiotIntegrationController < Api::V1::BaseController
  def sync_status
    players = organization_scoped(Player)

    # Calculate statistics
    total_players = players.count
    synced_players = players.where(sync_status: 'success').count
    pending_sync = players.where(sync_status: ['pending', nil]).or(players.where(sync_status: nil)).count
    failed_sync = players.where(sync_status: 'error').count

    # Players synced in last 24 hours
    recently_synced = players.where('last_sync_at > ?', 24.hours.ago).count

    # Players that need sync (never synced or synced more than 1 hour ago)
    needs_sync = players.where(last_sync_at: nil)
                       .or(players.where('last_sync_at < ?', 1.hour.ago))
                       .count

    # Get recent syncs (last 10)
    recent_syncs = players
                    .where.not(last_sync_at: nil)
                    .order(last_sync_at: :desc)
                    .limit(10)
                    .map do |player|
      {
        id: player.id,
        summoner_name: player.summoner_name,
        last_sync_at: player.last_sync_at,
        sync_status: player.sync_status || 'pending'
      }
    end

    render_success({
      stats: {
        total_players: total_players,
        synced_players: synced_players,
        pending_sync: pending_sync,
        failed_sync: failed_sync,
        recently_synced: recently_synced,
        needs_sync: needs_sync
      },
      recent_syncs: recent_syncs
    })
  end
end
