# frozen_string_literal: true

class SyncPlayerJob < ApplicationJob
  include RankComparison

  queue_as :default

  retry_on RiotApiService::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on RiotApiService::RiotApiError, wait: 1.minute, attempts: 3

  def perform(player_id, region = 'BR')
    player = Player.find(player_id)
    riot_service = RiotApiService.new

    if player.riot_puuid.blank?
      sync_summoner_by_name(player, riot_service, region)
    else
      sync_summoner_by_puuid(player, riot_service, region)
    end

    sync_rank_info(player, riot_service, region) if player.riot_summoner_id.present?

    sync_champion_mastery(player, riot_service, region) if player.riot_puuid.present?

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

    return unless player.summoner_name != summoner_data[:summoner_name]

    player.update!(summoner_name: summoner_data[:summoner_name])
  end

  def sync_rank_info(player, riot_service, region)
    league_data = riot_service.get_league_entries(
      summoner_id: player.riot_summoner_id,
      region: region
    )

    update_attributes = {}

    if league_data[:solo_queue].present?
      solo = league_data[:solo_queue]
      update_attributes.merge!(
        solo_queue_tier: solo[:tier],
        solo_queue_rank: solo[:rank],
        solo_queue_lp: solo[:lp],
        solo_queue_wins: solo[:wins],
        solo_queue_losses: solo[:losses]
      )

      if should_update_peak?(player, solo[:tier], solo[:rank])
        update_attributes.merge!(
          peak_tier: solo[:tier],
          peak_rank: solo[:rank],
          peak_season: current_season
        )
      end
    end

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

  def current_season
    Time.current.year - 2025 # Season 1 was 2011
  end

  def load_champion_id_map
    DataDragonService.new.champion_id_map
  end
end
