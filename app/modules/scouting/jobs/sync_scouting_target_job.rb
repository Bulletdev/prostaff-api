# frozen_string_literal: true

module Scouting
  # Syncs a scouting target's Riot data (PUUID, rank, champion pool)
  # and updates their summoner name if it has changed.
  class SyncScoutingTargetJob < ApplicationJob
    include Players::Concerns::RankComparison

    queue_as :default

    retry_on RiotApiService::RateLimitError, wait: :polynomially_longer, attempts: 5
    retry_on RiotApiService::RiotApiError, wait: 1.minute, attempts: 3

    def perform(scouting_target_id, organization_id)
      # Set organization context for multi-tenant scoping
      Current.organization_id = organization_id

      target = ScoutingTarget.find(scouting_target_id)
      riot_service = RiotApiService.new

      resolve_puuid!(target, riot_service)
      sync_account_name!(target, riot_service)
      sync_league_entries!(target, riot_service)
      sync_mastery_data!(target, riot_service)
      sync_recent_performance!(target, riot_service)

      target.update!(last_sync_at: Time.current)
      Rails.logger.info("Successfully synced scouting target #{target.id}")
    rescue RiotApiService::NotFoundError => e
      Rails.logger.error("Scouting target not found in Riot API: #{target.summoner_name} - #{e.message}")
    rescue StandardError => e
      Rails.logger.error("Failed to sync scouting target #{target.id}: #{e.message}")
      raise
    ensure
      # Clean up context
      Current.organization_id = nil
    end

    private

    def resolve_puuid!(target, riot_service)
      return if target.riot_puuid.present?

      summoner_data = riot_service.get_summoner_by_name(
        summoner_name: target.summoner_name,
        region: target.region
      )
      target.update!(
        riot_puuid: summoner_data[:puuid],
        riot_summoner_id: summoner_data[:summoner_id]
      )
    end

    def sync_account_name!(target, riot_service)
      return unless target.riot_puuid.present?

      account_data = riot_service.get_account_by_puuid(
        puuid: target.riot_puuid,
        region: target.region
      )
      apply_account_name_change!(target, account_data)
    end

    def apply_account_name_change!(target, account_data)
      return unless account_data[:game_name].present? && account_data[:tag_line].present?

      new_name = "#{account_data[:game_name]}##{account_data[:tag_line]}"
      return if target.summoner_name == new_name

      Rails.logger.info("Scouting target #{target.id} name changed: #{target.summoner_name} → #{new_name}")
      target.update!(summoner_name: new_name)
    end

    def sync_league_entries!(target, riot_service)
      return unless target.riot_summoner_id.present?

      league_data = riot_service.get_league_entries(
        summoner_id: target.riot_summoner_id,
        region: target.region
      )
      update_rank_info(target, league_data)
    end

    def sync_mastery_data!(target, riot_service)
      return unless target.riot_puuid.present?

      mastery_data = riot_service.get_champion_mastery(
        puuid: target.riot_puuid,
        region: target.region
      )
      update_champion_pool(target, mastery_data)
    end

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
      SeasonHistoryUpdater.call(target: target, league_data: league_data)
    end

    def update_champion_pool(target, mastery_data)
      champion_id_map = load_champion_id_map
      champion_names = mastery_data.take(10).map do |mastery|
        champion_id_map[mastery[:champion_id]]
      end.compact

      target.update!(champion_pool: champion_names)
    end

    def load_champion_id_map
      DataDragonService.new.champion_id_map
    end

    def sync_recent_performance!(target, riot_service)
      perf = PerformanceAggregator.new(riot_service: riot_service)
                                  .call(puuid: target.riot_puuid, region: target.region)
      target.update!(recent_performance: perf) if perf
    end
  end
end
