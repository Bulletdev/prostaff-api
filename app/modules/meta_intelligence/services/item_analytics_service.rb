# frozen_string_literal: true

module MetaIntelligence
  module Services
    # Computes item effectiveness across three game states based on gold differential.
    #
    # Game state thresholds (gold diff at 15 minutes via match.metadata):
    #   - ahead:  gold_diff > +1500
    #   - even:   gold_diff between -1500 and +1500
    #   - behind: gold_diff < -1500
    #
    # Returns win rate and frequency of use per item per game state.
    #
    # @example Get item analytics for org scope
    #   service = MetaIntelligence::Services::ItemAnalyticsService.new(organization: org)
    #   data    = service.call
    #   # => { 3153 => { ahead: { win_rate: 68.0, games: 25, wins: 17 }, even: {...}, behind: {...} } }
    #
    # @example Get analytics for a specific patch
    #   MetaIntelligence::Services::ItemAnalyticsService.new(organization: org, patch: '14.24').call
    class ItemAnalyticsService
      GOLD_DIFF_AHEAD_THRESHOLD  =  1500
      GOLD_DIFF_BEHIND_THRESHOLD = -1500

      # @param organization [Organization]
      # @param scope [String] 'org' or 'org+scouting'
      # @param patch [String, nil] e.g. '14.24', nil means all patches
      def initialize(organization:, scope: 'org', patch: nil)
        @organization = organization
        @scope        = scope
        @patch        = patch
      end

      # Runs the analytics computation.
      # @return [Hash{Integer => Hash}] item_id => { ahead:, even:, behind: }
      def call
        stats = fetch_stats
        build_item_analytics(stats)
      end

      private

      def fetch_stats
        scope = build_base_scope
        scope = apply_patch_filter(scope) if @patch.present?
        scope.includes(:match).select(:items, :match_id)
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

      # --- Analytics ---

      def build_item_analytics(stats)
        # { item_id => { ahead: [true/false, ...], even: [...], behind: [...] } }
        item_outcomes = Hash.new { |h, k| h[k] = { ahead: [], even: [], behind: [] } }

        stats.each do |stat|
          game_state = determine_game_state(stat.match)
          victory    = stat.match&.victory? || false

          stat.items.compact.reject(&:zero?).each do |item_id|
            item_outcomes[item_id][game_state] << victory
          end
        end

        compute_win_rates(item_outcomes)
      end

      def determine_game_state(match)
        gold_diff = extract_gold_diff(match)

        if gold_diff > GOLD_DIFF_AHEAD_THRESHOLD
          :ahead
        elsif gold_diff < GOLD_DIFF_BEHIND_THRESHOLD
          :behind
        else
          :even
        end
      end

      def extract_gold_diff(match)
        return 0 unless match&.metadata.is_a?(Hash)

        match.metadata['gold_diff_at_15'].to_i
      end

      def compute_win_rates(item_outcomes)
        item_outcomes.transform_values do |states|
          states.transform_values { |outcomes| summarize_outcomes(outcomes) }
        end
      end

      def summarize_outcomes(outcomes)
        return { win_rate: 0.0, games: 0, wins: 0 } if outcomes.empty?

        wins  = outcomes.count(true)
        games = outcomes.size
        { win_rate: (wins.to_f / games * 100).round(2), games: games, wins: wins }
      end

      def scouting_scope?
        @scope == 'org+scouting'
      end
    end
  end
end
