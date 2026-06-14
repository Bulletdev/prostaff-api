# frozen_string_literal: true

# Loads champion patch win-rate data from champion_patch_winrate.json and
# exposes fast lookups cached in Rails.cache for 24 hours.
#
# Key format in JSON: "Azir_16" => 0.582
# where the suffix is the major integer of the patch (e.g. "16.08" -> "16").
#
# When patch is nil, the lookup falls back to the latest patch major version
# available in the data file so callers always receive a value when data exists.
class ChampionWinrateService
  PRIMARY_FILE = Rails.root.join('data', 'champion_patch_winrate.json').freeze
  FALLBACK_FILE = Pathname.new('/home/bullet/PROJETOS/prostaff-ml/data/champion_patch_winrate.json').freeze
  CACHE_KEY = 'champion_winrates'
  LATEST_PATCH_CACHE_KEY = 'champion_winrates_latest_patch'
  CACHE_TTL = 24.hours

  # Returns the win rate (Float) for a given champion on a given patch.
  # When patch is nil, falls back to the latest patch available in the data.
  # Returns nil only when champion is blank or no data exists at all.
  #
  # @param champion [String] e.g. "Azir"
  # @param patch    [String, Integer, nil] e.g. "16.08", 16, or nil
  # @return [Float, nil]
  def self.win_rate_for(champion:, patch:)
    return nil if champion.blank?

    effective_patch = patch.presence || latest_patch
    return nil if effective_patch.nil?

    major    = effective_patch.to_s.split('.').first
    alt_name = champion.gsub(/([a-z])([A-Z])/, '\1 \2') # "LeeSin" -> "Lee Sin"

    result = data["#{champion}_#{major}"] || data["#{alt_name}_#{major}"]

    if result.nil? && patch.present? && major != latest_patch
      result = data["#{champion}_#{latest_patch}"] || data["#{alt_name}_#{latest_patch}"]
    end

    result
  end

  # Returns a hash mapping each champion name to its win rate (or nil).
  #
  # @param champions [Array<String>]
  # @param patch     [String, nil]
  # @return [Hash{String => Float, nil}]
  def self.bulk_lookup(champions, patch)
    Array(champions).to_h { |c| [c, win_rate_for(champion: c, patch: patch)] }
  end

  # Returns the highest patch major version present in the data, or nil if
  # the data hash is empty.
  #
  # @return [String, nil]
  def self.latest_patch
    Rails.cache.fetch(LATEST_PATCH_CACHE_KEY, expires_in: CACHE_TTL) do
      majors = data.keys.filter_map { |k| k.split('_').last.to_i if k.match?(/\A.+_\d+\z/) }
      majors.max&.to_s
    end
  end

  # Loads (and caches) the win-rate JSON. Returns {} on any error.
  #
  # @return [Hash{String => Float}]
  def self.data
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      file_path = resolve_file_path
      if file_path
        JSON.parse(File.read(file_path))
      else
        Rails.logger.warn '[WINRATE] ChampionWinrateService: champion_patch_winrate.json not found in any known path'
        {}
      end
    rescue StandardError => e
      Rails.logger.warn "[WINRATE] ChampionWinrateService: failed to load win-rate data — #{e.message}"
      {}
    end
  end

  # @return [Pathname, nil]
  def self.resolve_file_path
    return PRIMARY_FILE  if PRIMARY_FILE.exist?
    return FALLBACK_FILE if FALLBACK_FILE.exist?

    nil
  end

  private_class_method :resolve_file_path
end
