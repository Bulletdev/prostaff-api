# frozen_string_literal: true

require 'net/http'

# Lightweight scheduled job that pings the Riot platform status endpoint every 6 hours.
# Purpose: keep the prostaff:job_heartbeat:RiotApiPingJob key alive in Redis so that
# StatusSnapshotJob correctly reports the Riot API as operational.
# Uses /lol/status/v4/platform-data — does not consume player-data rate limit quota.
class RiotApiPingJob < ApplicationJob
  queue_as :low

  PING_REGION  = 'br1'
  PING_TIMEOUT = 10

  def perform
    api_key = ENV['RIOT_API_KEY']
    unless api_key.present?
      Rails.logger.warn('[RIOT PING] RIOT_API_KEY not configured — skipping')
      return
    end

    ping_riot_status_api(api_key)
  end

  private

  def ping_riot_status_api(api_key)
    uri = URI("https://#{PING_REGION}.api.riotgames.com/lol/status/v4/platform-data")
    request = Net::HTTP::Get.new(uri)
    request['X-Riot-Token'] = api_key

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                                                       open_timeout: PING_TIMEOUT,
                                                       read_timeout: PING_TIMEOUT) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info('[RIOT PING] Riot API reachable')
      record_job_heartbeat
    else
      Rails.logger.warn("[RIOT PING] Riot API returned #{response.code} — heartbeat not written")
    end
  rescue StandardError => e
    Rails.logger.warn("[RIOT PING] Riot API unreachable: #{e.message}")
  end
end
