# frozen_string_literal: true

require 'net/https'

module Scouting
  # Enriches MarketRegistration records where solo_queue_id is NULL.
  #
  # Triggered by SyncGcdJob after each nightly sync. Attempts three sources in order:
  #
  #   1. DeepLOL strm_pro_info — primary, covers most main-roster players
  #   2. DeepLOL autocomplete  — fallback for slug mismatches (e.g. Pyeonsik → Pyeonsick)
  #   3. lolpros.gg search API — fallback for players not in DeepLOL (EMEA, coaches)
  #
  # On success: updates solo_queue_id with the highest-ranked account found.
  # On failure: marks tag_enriched: true to stop retrying until next sync resets the flag.
  class EnrichNullSoloQueueJob
    include Sidekiq::Job

    sidekiq_options queue: 'default', retry: 2

    DEEPLOL_HOST    = 'b2c-api-cdn.deeplol.gg'
    LOLPROS_HOST    = 'api.lolpros.gg'
    PRO_INFO_PATH   = '/summoner/strm_pro_info'
    AUTOCOMPLETE_PATH = '/summoner/pro-search-auto-complete'
    LOLPROS_PATH    = '/es/search'
    REQUEST_TIMEOUT = 5

    def perform(registration_id)
      reg = MarketRegistration.find_by(id: registration_id)
      return unless reg
      return if reg.solo_queue_id.present? || reg.solo_queue_id_override.present? || reg.tag_enriched

      slug    = deeplol_slug(reg.player_external_name)
      riot_id = fetch_riot_id(slug, reg.player_external_name)

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

    def fetch_riot_id(slug, player_name)
      result = call_deeplol(slug)
      return result if result

      url_name = autocomplete_slug(player_name)
      if url_name && url_name != slug
        result = call_deeplol(url_name)
        return result if result
      end

      lolpros_riot_id(player_name)
    end

    # ── DeepLOL ────────────────────────────────────────────────────────

    # Mirrors _leaguepedia_to_deeplol_slug from providers/deeplol.py.
    # "Frozen (Kim Tae-il)" -> "Frozen-Kim_Tae-il"
    # "Pyeonsik"            -> "Pyeonsik"
    def deeplol_slug(name)
      name = name.to_s.strip
      m = name.match(/\A(.+?)\s*\((.+?)\)\z/)
      return name unless m

      first  = m[1].strip.tr(' ', '-')
      second = m[2].strip.tr(' ', '_')
      "#{first}-#{second}"
    end

    def call_deeplol(slug)
      query    = URI.encode_www_form(status: 'pro', name: slug)
      response = http_get("#{PRO_INFO_PATH}?#{query}", host: DEEPLOL_HOST)
      return nil unless response.is_a?(Net::HTTPSuccess)

      accounts = Array(JSON.parse(response.body)['account_list'])
      return nil if accounts.empty?

      best     = accounts.max_by { |a| a['last_game_date'] || 0 }
      riot_id  = best['riot_id'].to_s.strip
      riot_tag = best['riot_tag'].to_s.strip

      return nil if riot_id.empty? || riot_tag.empty?

      "#{riot_id}##{riot_tag}"
    rescue StandardError => e
      Rails.logger.debug("[EnrichNullSoloQueueJob] call_deeplol failed slug=#{slug}: #{e.message}")
      nil
    end

    def autocomplete_slug(name)
      query    = URI.encode_www_form(search_string: name, riot_id_tag_line: '')
      response = http_get("#{AUTOCOMPLETE_PATH}?#{query}", host: DEEPLOL_HOST)
      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).dig('pro', 0, 'url_name')
    rescue StandardError
      nil
    end

    # ── lolpros.gg ─────────────────────────────────────────────────────

    # Strips parenthetical from Leaguepedia names for lolpros search.
    # "Albi (Albert Bera)" -> "Albi"
    # "Canyon"             -> "Canyon"
    def lolpros_query(player_name)
      player_name.to_s.strip.sub(/\s*\(.*\)\z/, '').strip
    end

    def lolpros_riot_id(player_name)
      query    = lolpros_query(player_name)
      response = http_get("#{LOLPROS_PATH}?#{URI.encode_www_form(query: query)}", host: LOLPROS_HOST)
      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      return nil if data.empty?

      entry = data[0]
      return nil unless entry['name'].to_s.casecmp?(query)

      accounts = Array(entry.dig('league_player', 'accounts'))
      return nil if accounts.empty?

      best     = accounts.max_by { |a| a.dig('rank', 'score') || 0 }
      gamename = best['gamename'].to_s.strip
      tagline  = best['tagline'].to_s.strip

      return nil if gamename.empty? || tagline.empty?

      "#{gamename}##{tagline}"
    rescue StandardError => e
      Rails.logger.debug("[EnrichNullSoloQueueJob] lolpros_riot_id failed #{player_name}: #{e.message}")
      nil
    end

    # ── HTTP ───────────────────────────────────────────────────────────

    def http_get(path, host:)
      http              = Net::HTTP.new(host, 443)
      http.use_ssl      = true
      http.open_timeout = REQUEST_TIMEOUT
      http.read_timeout = REQUEST_TIMEOUT
      http.get(path)
    end
  end
end
