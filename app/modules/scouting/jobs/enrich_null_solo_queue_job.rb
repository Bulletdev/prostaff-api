# frozen_string_literal: true

require 'net/https'

module Scouting
  # Enriches MarketRegistration records where solo_queue_id is NULL.
  #
  # Triggered by SyncGcdJob after each nightly sync. Calls the DeepLOL public
  # CDN API to resolve a pro player name to a full Riot ID (gameName#tagLine).
  # No authentication required — URL is hardcoded, no user input in the URI.
  #
  # On success: updates solo_queue_id with the most recently active account.
  # On failure (player not in DeepLOL): marks tag_enriched: true so we stop
  # retrying until the next sync resets the flag.
  class EnrichNullSoloQueueJob
    include Sidekiq::Job

    sidekiq_options queue: 'default', retry: 2

    DEEPLOL_HOST = 'b2c-api-cdn.deeplol.gg'
    DEEPLOL_PATH = '/summoner/strm_pro_info'
    REQUEST_TIMEOUT = 5

    def perform(registration_id)
      reg = MarketRegistration.find_by(id: registration_id)
      return unless reg
      return if reg.solo_queue_id.present? || reg.solo_queue_id_override.present? || reg.tag_enriched

      slug = deeplol_slug(reg.player_external_name)
      riot_id = fetch_riot_id(slug)

      if riot_id
        reg.update!(solo_queue_id: riot_id)
        Rails.logger.info("[EnrichNullSoloQueueJob] #{reg.player_external_name} -> #{riot_id}")
      else
        reg.update!(tag_enriched: true)
        Rails.logger.debug("[EnrichNullSoloQueueJob] Not found: #{reg.player_external_name} (slug=#{slug})")
      end
    rescue StandardError => e
      Rails.logger.error("[EnrichNullSoloQueueJob] reg=#{registration_id}: #{e.message}")
    end

    private

    # Mirrors _leaguepedia_to_deeplol_slug from providers/deeplol.py.
    # "Frozen (Kim Tae-il)" -> "Frozen-Kim_Tae-il"
    # "Pyeonsik"            -> "Pyeonsik"
    def deeplol_slug(name)
      name = name.to_s.strip
      m = name.match(/\A(.+?)\s*\((.+?)\)\z/)
      return name unless m

      first = m[1].strip.tr(' ', '-')
      second = m[2].strip.tr(' ', '_')
      "#{first}-#{second}"
    end

    def fetch_riot_id(slug)
      query = URI.encode_www_form(status: 'pro', name: slug)
      path  = "#{DEEPLOL_PATH}?#{query}"

      http = Net::HTTP.new(DEEPLOL_HOST, 443)
      http.use_ssl      = true
      http.open_timeout = REQUEST_TIMEOUT
      http.read_timeout = REQUEST_TIMEOUT

      response = http.get(path)
      return nil unless response.is_a?(Net::HTTPSuccess)

      accounts = Array(JSON.parse(response.body)['account_list'])
      return nil if accounts.empty?

      best     = accounts.max_by { |a| a['last_game_date'] || 0 }
      riot_id  = best['riot_id'].to_s.strip
      riot_tag = best['riot_tag'].to_s.strip

      return nil if riot_id.empty? || riot_tag.empty?

      "#{riot_id}##{riot_tag}"
    rescue StandardError => e
      Rails.logger.debug("[EnrichNullSoloQueueJob] fetch_riot_id failed slug=#{slug}: #{e.message}")
      nil
    end
  end
end
