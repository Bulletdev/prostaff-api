class SyncScoutingTargetJob < ApplicationJob
  queue_as :default

  retry_on RiotApiService::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on RiotApiService::RiotApiError, wait: 1.minute, attempts: 3

  def perform(scouting_target_id)
    target = ScoutingTarget.find(scouting_target_id)
    riot_service = RiotApiService.new

    # Get summoner info
    if target.riot_puuid.blank?
      summoner_data = riot_service.get_summoner_by_name(
        summoner_name: target.summoner_name,
        region: target.region
      )

      target.update!(
        riot_puuid: summoner_data[:puuid],
        riot_summoner_id: summoner_data[:summoner_id]
      )
    end

    # Get rank information
    if target.riot_summoner_id.present?
      league_data = riot_service.get_league_entries(
        summoner_id: target.riot_summoner_id,
        region: target.region
      )

      update_rank_info(target, league_data)
    end

    # Get champion mastery for champion pool
    if target.riot_puuid.present?
      mastery_data = riot_service.get_champion_mastery(
        puuid: target.riot_puuid,
        region: target.region
      )

      update_champion_pool(target, mastery_data)
    end

    # Update last sync
    target.update!(last_sync_at: Time.current)

    Rails.logger.info("Successfully synced scouting target #{target.id}")

  rescue RiotApiService::NotFoundError => e
    Rails.logger.error("Scouting target not found in Riot API: #{target.summoner_name} - #{e.message}")
  rescue StandardError => e
    Rails.logger.error("Failed to sync scouting target #{target.id}: #{e.message}")
    raise
  end

  private

  def update_rank_info(target, league_data)
    update_attributes = {}

    if league_data[:solo_queue].present?
      solo = league_data[:solo_queue]
      update_attributes.merge!(
        current_tier: solo[:tier],
        current_rank: solo[:rank],
        current_lp: solo[:lp]
      )

      # Update peak if current is higher
      if should_update_peak?(target, solo[:tier], solo[:rank])
        update_attributes.merge!(
          peak_tier: solo[:tier],
          peak_rank: solo[:rank]
        )
      end
    end

    target.update!(update_attributes) if update_attributes.present?
  end

  def update_champion_pool(target, mastery_data)
    # Get top 10 champions
    champion_id_map = load_champion_id_map
    champion_names = mastery_data.take(10).map do |mastery|
      champion_id_map[mastery[:champion_id]]
    end.compact

    target.update!(champion_pool: champion_names)
  end

  def should_update_peak?(target, new_tier, new_rank)
    return true if target.peak_tier.blank?

    tier_values = %w[IRON BRONZE SILVER GOLD PLATINUM EMERALD DIAMOND MASTER GRANDMASTER CHALLENGER]
    rank_values = %w[IV III II I]

    current_tier_index = tier_values.index(target.peak_tier&.upcase) || 0
    new_tier_index = tier_values.index(new_tier&.upcase) || 0

    return true if new_tier_index > current_tier_index
    return false if new_tier_index < current_tier_index

    # Same tier, compare ranks
    current_rank_index = rank_values.index(target.peak_rank&.upcase) || 0
    new_rank_index = rank_values.index(new_rank&.upcase) || 0

    new_rank_index > current_rank_index
  end

  def load_champion_id_map
    Rails.cache.fetch('riot:champion_id_map', expires_in: 1.week) do
      {}
    end
  end
end
