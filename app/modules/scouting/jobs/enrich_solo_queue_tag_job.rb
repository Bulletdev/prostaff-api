# frozen_string_literal: true

module Scouting
  # Enriches a MarketRegistration's solo_queue_id with the #TAGLINE from Riot API.
  #
  # Triggered by SyncGcdJob for records where solo_queue_id has no '#'.
  # Uses the existing RiotApiService (riot-gateway) for rate limiting and circuit breaking.
  # Marks tag_enriched: true on success OR when the player cannot be found,
  # to prevent infinite re-queuing.
  class EnrichSoloQueueTagJob
    include Sidekiq::Job

    sidekiq_options queue: 'default', retry: 2

    def perform(registration_id)
      reg = MarketRegistration.find_by(id: registration_id)
      return unless reg&.needs_tag_enrichment?

      riot = RiotApiService.new
      summoner = riot.get_summoner_by_name(
        summoner_name: reg.solo_queue_id,
        region: reg.solo_queue_server
      )

      return reg.update!(tag_enriched: true) unless summoner&.dig(:puuid)

      account = riot.get_account_by_puuid(
        puuid: summoner[:puuid],
        region: reg.solo_queue_server
      )

      return reg.update!(tag_enriched: true) unless account&.dig(:tag_line)

      full_id = "#{account[:game_name]}##{account[:tag_line]}"
      reg.update!(solo_queue_id: full_id, tag_enriched: true)

      Rails.logger.info(
        "[EnrichSoloQueueTagJob] #{reg.player_external_name}: #{reg.solo_queue_id} -> #{full_id}"
      )
    rescue RiotApiService::RateLimitError => e
      Rails.logger.warn("[EnrichSoloQueueTagJob] Rate limited for registration_id=#{registration_id}: #{e.message}")
      raise
    rescue RiotApiService::RiotApiError => e
      # NotFoundError (404/410) and other permanent API failures — stop retrying
      Rails.logger.warn("[EnrichSoloQueueTagJob] Permanent API failure reg=#{registration_id}: #{e.message}")
      reg&.update!(tag_enriched: true)
    rescue StandardError => e
      Rails.logger.error("[EnrichSoloQueueTagJob] registration_id=#{registration_id}: #{e.message}")
    end
  end
end
