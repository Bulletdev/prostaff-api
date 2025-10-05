class SyncPlayerJob < ApplicationJob
  queue_as :default

  retry_on RiotApiService::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on RiotApiService::RiotApiError, wait: 1.minute, attempts: 3

  def perform(player_id, region = 'BR')
    player = Player.find(player_id)
    riot_service = RiotApiService.new

    # Skip if player doesn't have PUUID yet
    if player.riot_puuid.blank?
      sync_summoner_by_name(player, riot_service, region)
    else
      sync_summoner_by_puuid(player, riot_service, region)
    end

    # Update rank information
    sync_rank_info(player, riot_service, region) if player.riot_summoner_id.present?

    # Update champion mastery
    sync_champion_mastery(player, riot_service, region) if player.riot_puuid.present?

    # Update last sync timestamp
    player.update!(last_sync_at: Time.current)

  rescue RiotApiService::NotFoundError => e
    Rails.logger.error("Player not found in Riot API: #{player.summoner_name} - #{e.message}")
  rescue RiotApiService::UnauthorizedError => e
    Rails.logger.error("Riot API authentication failed: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("Failed to sync player #{player.id}: #{e.message}")
    raise
  end

  private

  def sync_summoner_by_name(player, riot_service, region)
    summoner_data = riot_service.get_summoner_by_name(
      summoner_name: player.summoner_name,
      region: region
    )

    player.update!(
      riot_puuid: summoner_data[:puuid],
      riot_summoner_id: summoner_data[:summoner_id]
    )
  end

  def sync_summoner_by_puuid(player, riot_service, region)
    summoner_data = riot_service.get_summoner_by_puuid(
      puuid: player.riot_puuid,
      region: region
    )

    # Update summoner name if changed
    if player.summoner_name != summoner_data[:summoner_name]
      player.update!(summoner_name: summoner_data[:summoner_name])
    end
  end

  def sync_rank_info(player, riot_service, region)
    league_data = riot_service.get_league_entries(
      summoner_id: player.riot_summoner_id,
      region: region
    )

    update_attributes = {}

    # Solo Queue
    if league_data[:solo_queue].present?
      solo = league_data[:solo_queue]
      update_attributes.merge!(
        solo_queue_tier: solo[:tier],
        solo_queue_rank: solo[:rank],
        solo_queue_lp: solo[:lp],
        solo_queue_wins: solo[:wins],
        solo_queue_losses: solo[:losses]
      )

      # Update peak if current is higher
      if should_update_peak?(player, solo[:tier], solo[:rank])
        update_attributes.merge!(
          peak_tier: solo[:tier],
          peak_rank: solo[:rank],
          peak_season: current_season
        )
      end
    end

    # Flex Queue
    if league_data[:flex_queue].present?
      flex = league_data[:flex_queue]
      update_attributes.merge!(
        flex_queue_tier: flex[:tier],
        flex_queue_rank: flex[:rank],
        flex_queue_lp: flex[:lp]
      )
    end

    player.update!(update_attributes) if update_attributes.present?
  end

  def sync_champion_mastery(player, riot_service, region)
    mastery_data = riot_service.get_champion_mastery(
      puuid: player.riot_puuid,
      region: region
    )

    # Get champion static data (you would need a champion ID to name mapping)
    champion_id_map = load_champion_id_map

    mastery_data.take(20).each do |mastery|
      champion_name = champion_id_map[mastery[:champion_id]]
      next unless champion_name

      champion_pool = player.champion_pools.find_or_initialize_by(champion: champion_name)
      champion_pool.update!(
        mastery_level: mastery[:champion_level],
        mastery_points: mastery[:champion_points],
        last_played_at: mastery[:last_played]
      )
    end
  end

  def should_update_peak?(player, new_tier, new_rank)
    return true if player.peak_tier.blank?

    tier_values = %w[IRON BRONZE SILVER GOLD PLATINUM EMERALD DIAMOND MASTER GRANDMASTER CHALLENGER]
    rank_values = %w[IV III II I]

    current_tier_index = tier_values.index(player.peak_tier&.upcase) || 0
    new_tier_index = tier_values.index(new_tier&.upcase) || 0

    return true if new_tier_index > current_tier_index
    return false if new_tier_index < current_tier_index

    # Same tier, compare ranks
    current_rank_index = rank_values.index(player.peak_rank&.upcase) || 0
    new_rank_index = rank_values.index(new_rank&.upcase) || 0

    new_rank_index > current_rank_index
  end

  def current_season
    # This should be dynamic based on Riot's current season
    Time.current.year - 2010 # Season 1 was 2011
  end

  def load_champion_id_map
    # This is a simplified version. In production, you would load this from Data Dragon
    # or cache it in Redis
    Rails.cache.fetch('riot:champion_id_map', expires_in: 1.week) do
      # Fetch from Data Dragon API or use a static file
      # For now, return an empty hash
      {}
    end
  end
end
