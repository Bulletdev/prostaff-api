# frozen_string_literal: true

module AiIntelligence
  module Services
    # Loads champion patch win-rate data from champion_patch_winrate.json and
    # exposes fast lookups cached in Rails.cache for 24 hours.
    #
    # Key format in JSON: "Azir_16" => 0.582
    # where the suffix is the major integer of the patch (e.g. "16.08" -> "16").
    class ChampionWinrateService
      PRIMARY_FILE = Rails.root.join('data', 'champion_patch_winrate.json').freeze
      FALLBACK_FILE = Pathname.new('/home/bullet/PROJETOS/prostaff-ml/data/champion_patch_winrate.json').freeze
      CACHE_KEY = 'champion_winrates'
      CACHE_TTL = 24.hours

      # Returns the win rate (Float) for a given champion on a given patch,
      # or nil if no data is available.
      #
      # @param champion [String] e.g. "Azir"
      # @param patch    [String] e.g. "16.08"  or Integer 16
      # @return [Float, nil]
      def self.win_rate_for(champion:, patch:)
        return nil if champion.blank? || patch.nil?

        key = "#{champion}_#{patch.to_s.split('.').first}"
        data[key]
      end

      # Returns a hash mapping each champion name to its win rate (or nil).
      #
      # @param champions [Array<String>]
      # @param patch     [String]
      # @return [Hash{String => Float, nil}]
      def self.bulk_lookup(champions, patch)
        Array(champions).map { |c| [c, win_rate_for(champion: c, patch: patch)] }.to_h
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
            Rails.logger.warn 'ChampionWinrateService: champion_patch_winrate.json not found in any known path'
            {}
          end
        rescue => e
          Rails.logger.warn "ChampionWinrateService: failed to load win-rate data — #{e.message}"
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
  end
end
