# frozen_string_literal: true

module Matches
  # Background job that fetches match history from Riot API for a specific player
  # and queues individual SyncMatchJob jobs for each match to import.
  class ImportPlayerMatchesJob < ApplicationJob
    queue_as :default

    def perform(player_id, organization_id, count = 20)
      Current.organization_id = organization_id

      organization = Organization.find(organization_id)
      player = organization.players.find(player_id)

      return unless player.riot_puuid.present?

      riot_service = RiotApiService.new
      region = player.region || 'BR'

      match_ids = riot_service.get_match_history(
        puuid: player.riot_puuid,
        region: region,
        count: count
      )

      match_ids.each do |match_id|
        next if Match.exists?(riot_match_id: match_id)

        SyncMatchJob.perform_later(match_id, organization_id, region)
      end
    rescue RiotApiService::RiotApiError => e
      Rails.logger.error("ImportPlayerMatchesJob: Riot API error for player #{player_id}: #{e.message}")
    rescue StandardError => e
      Rails.logger.error("ImportPlayerMatchesJob: Unexpected error for player #{player_id}: #{e.class} - #{e.message}")
      raise
    ensure
      Current.organization_id = nil
    end
  end
end
