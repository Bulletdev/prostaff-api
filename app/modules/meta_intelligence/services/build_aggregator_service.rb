# frozen_string_literal: true

module MetaIntelligence
  module Services
    # Aggregates match history into build performance records (saved_builds).
    #
    # Groups player_match_stats by champion + role (not by exact item set).
    # This makes win rate statistics meaningful even with limited match history
    # (e.g. a team's own ~300 games vs the millions needed for exact-build grouping).
    #
    # For each champion+role group:
    #   - Win rate is calculated across ALL games on that champion in that role.
    #   - The most frequently used item build is stored as the representative build.
    #   - Runes, spells, and build order are derived from the most common occurrence.
    #
    # Supports two data scopes:
    #   - 'org'          — only the organization's own matches (default)
    #   - 'org+scouting' — org matches + scouting target matches
    #
    # @example Aggregate for the organization
    #   result = MetaIntelligence::Services::BuildAggregatorService.new(organization: org).call
    #   # => { upserted: 12, skipped: 3, errors: 0 }
    #
    # @example Aggregate for a specific patch
    #   MetaIntelligence::Services::BuildAggregatorService.new(organization: org, patch: '14.24').call
    class BuildAggregatorService
      # Minimum number of games to include a champion+role record.
      # Set to 2 to surface meaningful data even for small team datasets.
      MINIMUM_SAMPLE_SIZE = 2

      STAT_COLUMNS = %i[
        champion role items runes primary_rune_tree secondary_rune_tree
        summoner_spell_1 summoner_spell_2 item_build_order trinket
        kills deaths assists cs_per_min damage_share match_id
      ].freeze

      # @param organization [Organization]
      # @param scope [String] 'org' or 'org+scouting'
      # @param patch [String, nil] e.g. '14.24', nil means all patches
      def initialize(organization:, scope: 'org', patch: nil)
        @organization = organization
        @scope        = scope
        @patch        = patch
      end

      # Runs the full aggregation pipeline.
      # @return [Hash] { upserted: Integer, skipped: Integer, errors: Integer }
      def call
        stats   = fetch_stats
        grouped = group_by_champion_role(stats)
        process_groups(grouped)
      end

      private

      # --- Data Fetching ---

      def fetch_stats
        scope = build_base_scope
        scope = apply_patch_filter(scope) if @patch.present?
        scope.includes(:match).select(*STAT_COLUMNS)
      end

      def build_base_scope
        return org_stats unless scouting_scope?

        org_match_ids = @organization.matches.select(:id)

        PlayerMatchStat
          .where(match_id: org_match_ids)
          .or(PlayerMatchStat.where(player_id: scouting_player_ids))
          .where('array_length(items, 1) > 0')
      end

      # Resolves scouting watchlist entries to internal Player IDs via riot_puuid.
      # ScoutingTarget is a global model; Player is org-specific — linked by riot_puuid.
      def scouting_player_ids
        scouting_target_ids = ScoutingWatchlist.where(organization_id: @organization.id)
                                               .pluck(:scouting_target_id)
        puuids = ScoutingTarget.where(id: scouting_target_ids).pluck(:riot_puuid).compact
        Player.where(riot_puuid: puuids).pluck(:id)
      end

      def org_stats
        org_match_ids = @organization.matches.select(:id)
        PlayerMatchStat
          .where(match_id: org_match_ids)
          .where('array_length(items, 1) > 0')
      end

      def apply_patch_filter(scope)
        patch_match_ids = Match.where(game_version: @patch).select(:id)
        scope.where(match_id: patch_match_ids)
      end

      # --- Grouping ---

      # Groups stats by champion + role (ignoring exact item set).
      # Win rate is calculated across all games on that champion+role.
      # The most common item build is extracted as the representative build.
      def group_by_champion_role(stats)
        stats.group_by { |stat| [stat.champion, stat.role] }
      end

      # --- Processing ---

      def process_groups(grouped)
        result = { upserted: 0, skipped: 0, errors: 0 }

        grouped.each do |key, stats|
          if stats.size < MINIMUM_SAMPLE_SIZE
            result[:skipped] += 1
            next
          end

          upsert_build(key, stats)
          result[:upserted] += 1
        rescue StandardError => e
          Rails.logger.error("[MetaIntelligence] Aggregation error for #{key}: #{e.message}")
          result[:errors] += 1
        end

        result
      end

      def upsert_build(key, stats)
        champion, role = key
        fingerprint    = stable_fingerprint(champion, role)
        metrics        = compute_metrics(stats)
        build_data     = find_most_common_build(stats)

        build = find_or_init_build(champion, role, fingerprint)
        apply_metrics(build, metrics, build_data)
        build.title ||= default_title(champion, role)
        build.save!
      end

      def find_or_init_build(champion, role, fingerprint)
        SavedBuild.find_or_initialize_by(
          organization: @organization,
          champion: champion,
          role: role,
          items_fingerprint: fingerprint,
          data_source: 'aggregated'
        )
      end

      def default_title(champion, role)
        [champion, role&.capitalize].compact.join(' ')
      end

      # Stable fingerprint based on champion+role (not item set).
      # This ensures the same record is updated on every aggregation run.
      def stable_fingerprint(champion, role)
        Digest::SHA256.hexdigest("#{champion}:#{role}")
      end

      # --- Metric Computation ---

      def apply_metrics(build, metrics, build_data)
        build.games_played            = metrics[:games_played]
        build.win_rate                = metrics[:win_rate]
        build.average_kda             = metrics[:average_kda]
        build.average_cs_per_min      = metrics[:average_cs_per_min]
        build.average_damage_share    = metrics[:average_damage_share]

        return unless build_data

        build.items                   = build_data[:items]
        build.item_build_order        = build_data[:item_build_order]
        build.trinket                 = build_data[:trinket]
        build.runes                   = build_data[:runes]
        build.primary_rune_tree       = build_data[:primary_rune_tree]
        build.secondary_rune_tree     = build_data[:secondary_rune_tree]
        build.summoner_spell_1        = build_data[:summoner_spell_1]
        build.summoner_spell_2        = build_data[:summoner_spell_2]
      end

      def compute_metrics(stats)
        wins = stats.count { |s| s.match&.victory? }
        {
          games_played:          stats.size,
          win_rate:              (wins.to_f / stats.size * 100).round(2),
          average_kda:           average_stat(stats, &method(:kda_for)),
          average_cs_per_min:    average_stat(stats) { |s| s.cs_per_min.to_f },
          average_damage_share:  average_stat(stats) { |s| s.damage_share.to_f }
        }
      end

      def kda_for(stat)
        return 0.0 if stat.deaths.to_i.zero?

        (stat.kills.to_i + stat.assists.to_i).to_f / stat.deaths.to_i
      end

      def average_stat(stats, &block)
        values = stats.filter_map { |s| block.call(s) }
        return 0.0 if values.empty?

        (values.sum / values.size.to_f).round(2)
      end

      # Returns the most frequently occurring complete build configuration.
      # Groups by item set, picks the largest group, uses its first entry as representative.
      def find_most_common_build(stats)
        by_items = stats.group_by { |s| s.items.compact.reject(&:zero?).sort }
        most_common_group = by_items.max_by { |_key, group| group.size }
        return nil unless most_common_group

        rep = most_common_group[1].first
        {
          items:               rep.items,
          item_build_order:    rep.item_build_order,
          trinket:             rep.trinket,
          runes:               rep.runes,
          primary_rune_tree:   rep.primary_rune_tree,
          secondary_rune_tree: rep.secondary_rune_tree,
          summoner_spell_1:    rep.summoner_spell_1,
          summoner_spell_2:    rep.summoner_spell_2
        }
      end

      # --- Helpers ---

      def scouting_scope?
        @scope == 'org+scouting'
      end
    end
  end
end
