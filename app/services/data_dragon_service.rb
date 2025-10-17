class DataDragonService
  BASE_URL = 'https://ddragon.leagueoflegends.com'.freeze

  class DataDragonError < StandardError; end

  def initialize
    @latest_version = nil
  end

  # Get the latest game version
  def latest_version
    @latest_version ||= fetch_latest_version
  end

  # Get champion ID to name mapping
  def champion_id_map
    Rails.cache.fetch('riot:champion_id_map', expires_in: 1.week) do
      fetch_champion_data
    end
  end

  # Get champion name to ID mapping (reverse)
  def champion_name_map
    Rails.cache.fetch('riot:champion_name_map', expires_in: 1.week) do
      champion_id_map.invert
    end
  end

  # Get all champions data (full details)
  def all_champions
    Rails.cache.fetch('riot:all_champions', expires_in: 1.week) do
      fetch_all_champions_data
    end
  end

  # Get specific champion data by key
  def champion_by_key(champion_key)
    all_champions[champion_key]
  end

  # Get profile icons data
  def profile_icons
    Rails.cache.fetch('riot:profile_icons', expires_in: 1.week) do
      fetch_profile_icons
    end
  end

  # Get summoner spells data
  def summoner_spells
    Rails.cache.fetch('riot:summoner_spells', expires_in: 1.week) do
      fetch_summoner_spells
    end
  end

  # Get items data
  def items
    Rails.cache.fetch('riot:items', expires_in: 1.week) do
      fetch_items
    end
  end

  # Clear all cached data
  def clear_cache!
    Rails.cache.delete('riot:champion_id_map')
    Rails.cache.delete('riot:champion_name_map')
    Rails.cache.delete('riot:all_champions')
    Rails.cache.delete('riot:profile_icons')
    Rails.cache.delete('riot:summoner_spells')
    Rails.cache.delete('riot:items')
    Rails.cache.delete('riot:latest_version')
    @latest_version = nil
  end

  private

  def fetch_latest_version
    cached_version = Rails.cache.read('riot:latest_version')
    return cached_version if cached_version.present?

    url = "#{BASE_URL}/api/versions.json"
    response = make_request(url)
    versions = JSON.parse(response.body)

    latest = versions.first
    Rails.cache.write('riot:latest_version', latest, expires_in: 1.day)
    latest
  rescue StandardError => e
    Rails.logger.error("Failed to fetch latest version: #{e.message}")
    # Fallback to a recent known version
    '14.1.1'
  end

  def fetch_champion_data
    version = latest_version
    url = "#{BASE_URL}/cdn/#{version}/data/en_US/champion.json"

    response = make_request(url)
    data = JSON.parse(response.body)

    # Create mapping: champion_id (integer) => champion_name (string)
    champion_map = {}
    data['data'].each do |_key, champion|
      champion_id = champion['key'].to_i
      champion_name = champion['id'] # This is the champion name like "Aatrox"
      champion_map[champion_id] = champion_name
    end

    champion_map
  rescue StandardError => e
    Rails.logger.error("Failed to fetch champion data: #{e.message}")
    {}
  end

  def fetch_all_champions_data
    version = latest_version
    url = "#{BASE_URL}/cdn/#{version}/data/en_US/champion.json"

    response = make_request(url)
    data = JSON.parse(response.body)

    data['data']
  rescue StandardError => e
    Rails.logger.error("Failed to fetch all champions data: #{e.message}")
    {}
  end

  def fetch_profile_icons
    version = latest_version
    url = "#{BASE_URL}/cdn/#{version}/data/en_US/profileicon.json"

    response = make_request(url)
    data = JSON.parse(response.body)

    data['data']
  rescue StandardError => e
    Rails.logger.error("Failed to fetch profile icons: #{e.message}")
    {}
  end

  def fetch_summoner_spells
    version = latest_version
    url = "#{BASE_URL}/cdn/#{version}/data/en_US/summoner.json"

    response = make_request(url)
    data = JSON.parse(response.body)

    data['data']
  rescue StandardError => e
    Rails.logger.error("Failed to fetch summoner spells: #{e.message}")
    {}
  end

  def fetch_items
    version = latest_version
    url = "#{BASE_URL}/cdn/#{version}/data/en_US/item.json"

    response = make_request(url)
    data = JSON.parse(response.body)

    data['data']
  rescue StandardError => e
    Rails.logger.error("Failed to fetch items: #{e.message}")
    {}
  end

  def make_request(url)
    conn = Faraday.new do |f|
      f.request :retry, max: 3, interval: 0.5, backoff_factor: 2
      f.adapter Faraday.default_adapter
    end

    response = conn.get(url) do |req|
      req.options.timeout = 10
    end

    unless response.success?
      raise DataDragonError, "Request failed with status #{response.status}"
    end

    response
  rescue Faraday::TimeoutError => e
    raise DataDragonError, "Request timeout: #{e.message}"
  rescue Faraday::Error => e
    raise DataDragonError, "Network error: #{e.message}"
  end
end
