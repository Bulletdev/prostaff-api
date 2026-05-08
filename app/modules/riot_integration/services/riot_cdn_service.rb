# frozen_string_literal: true

# Riot CDN Service
# Provides URLs for champion icons, items, runes, and other game assets
class RiotCdnService
  # Using a recent version as fallback/default.
  # Ideally this should be fetched dynamically from https://ddragon.leagueoflegends.com/api/versions.json
  DEFAULT_VERSION = '14.1.1'
  BASE_URL = 'https://ddragon.leagueoflegends.com/cdn'

  def initialize(version: nil)
    @version = version || cached_latest_version
  end

  # Fetches the latest Data Dragon version from Riot API with caching
  def cached_latest_version
    Rails.cache.fetch('riot_cdn_latest_version', expires_in: 1.hour) do
      fetch_latest_version
    end
  end

  # Fetches the latest Data Dragon version from Riot API
  def fetch_latest_version
    require 'net/http'
    require 'json'

    uri = URI('https://ddragon.leagueoflegends.com/api/versions.json')
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      versions = JSON.parse(response.body)
      versions.first # Returns the latest version
    else
      DEFAULT_VERSION
    end
  rescue StandardError => e
    Rails.logger.warn "Failed to fetch latest Data Dragon version: #{e.message}"
    DEFAULT_VERSION
  end

  def champion_icon_url(champion_name)
    return nil if champion_name.blank?

    # Handle special cases for champion names if necessary (e.g. Wukong -> MonkeyKing)
    # For now assuming standard Data Dragon naming convention
    normalized_name = normalize_champion_name(champion_name)
    "#{BASE_URL}/#{@version}/img/champion/#{normalized_name}.png"
  end

  def item_icon_url(item_id)
    return nil if item_id.blank? || item_id.zero?

    "#{BASE_URL}/#{@version}/img/item/#{item_id}.png"
  end

  def rune_icon_url(rune_id)
    return nil if rune_id.blank?

    # Runes are a bit different, they are often in a different path structure in newer ddragon versions
    # or sometimes just in img/perk. Let's try the standard perk path.
    # NOTE: Rune IDs in match history often map to specific paths.
    # A more robust implementation would need the runesReforged.json data.
    # For this MVP, we might need to adjust if IDs don't map directly to filenames.
    # Actually, many runes are at https://ddragon.leagueoflegends.com/cdn/img/perk/<id>.png
    # Let's use the most common path for perks/runes.
    "#{BASE_URL}/img/perk-images/Styles/#{rune_id}.png"
  end

  # Helper to get the full rune path if we had the full path from static data
  # For now, we'll try a simplified approach or just return a placeholder if we can't map it easily without the JSON
  def perk_icon_url(icon_path)
    return nil if icon_path.blank?

    "https://ddragon.leagueoflegends.com/cdn/img/#{icon_path}"
  end

  def profile_icon_url(icon_id)
    return nil if icon_id.blank?

    "#{BASE_URL}/#{@version}/img/profileicon/#{icon_id}.png"
  end

  def spell_icon_url(spell_id)
    # Spell IDs need to be mapped to names (e.g. 4 -> SummonerFlash)
    # This requires a static map.
    spell_name = summoner_spell_map[spell_id]
    return nil unless spell_name

    "#{BASE_URL}/#{@version}/img/spell/#{spell_name}.png"
  end

  private

  def normalize_champion_name(name)
    return nil if name.blank?

    # Basic normalization - remove spaces and special characters
    normalized = name.gsub("'", '').gsub(' ', '')

    # Add more specific overrides here if needed
    # Wukong is usually MonkeyKing in DDragon
    return 'MonkeyKing' if name.casecmp('wukong').zero?
    return 'Renata' if name.casecmp('renata glasc').zero?
    return 'Renata' if name.casecmp('renata').zero?

    # Handle special cases where name has spaces
    # Lee Sin -> LeeSin, Dr. Mundo -> DrMundo, etc.
    normalized
  end

  def summoner_spell_map
    @summoner_spell_map ||= {
      1 => 'SummonerBoost',
      3 => 'SummonerExhaust',
      4 => 'SummonerFlash',
      6 => 'SummonerHaste',
      7 => 'SummonerHeal',
      11 => 'SummonerSmite',
      12 => 'SummonerTeleport',
      13 => 'SummonerMana',
      14 => 'SummonerDot', # Ignite
      21 => 'SummonerBarrier',
      30 => 'SummonerPoroRecall',
      31 => 'SummonerPoroThrow',
      32 => 'SummonerSnowball',
      39 => 'SummonerSnowURFSnowball_Mark'
    }
  end
end
