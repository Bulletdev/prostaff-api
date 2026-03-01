# frozen_string_literal: true

module MetaIntelligence
  module Controllers
    # Provides item tier list and per-item analytics with win rates by game state.
    #
    # Game states are derived from gold differential at 15 minutes stored in
    # match.metadata['gold_diff_at_15']. When that field is absent, the stat
    # is attributed to the 'even' state.
    #
    # All endpoints are organization-scoped (multi-tenant safe).
    #
    # @example List item tier list
    #   GET /api/v1/meta/items?scope=org&patch=14.24&role=adc
    #
    # @example Get specific item stats
    #   GET /api/v1/meta/items/3153?scope=org
    class ItemsController < Api::V1::BaseController
      ALLOWED_SCOPES = %w[org org+scouting].freeze

      # GET /api/v1/meta/items
      #
      # @param [String] scope 'org' (default) or 'org+scouting'
      # @param [String] patch  e.g. '14.24' (optional)
      # @return [JSON] { data: { items: [...], total: Integer } }
      def index
        analytics     = run_item_analytics
        item_metadata = load_item_metadata(analytics.keys)
        tier_list     = build_tier_list(analytics, item_metadata)

        render_success(
          { items: tier_list, total: tier_list.size },
          message: 'Item analytics retrieved'
        )
      end

      # GET /api/v1/meta/items/:id
      #
      # @param [String] id Riot item ID (integer as string)
      # @return [JSON] { data: { item_id: Integer, analytics: { ahead:, even:, behind: } } }
      def show
        item_id   = params[:id].to_i
        analytics = run_item_analytics

        item_data = analytics[item_id]

        return render_error(message: 'Item not found in analytics', status: :not_found) unless item_data

        render_success(
          { item_id: item_id, analytics: item_data },
          message: 'Item stats retrieved'
        )
      end

      private

      def run_item_analytics
        ItemAnalyticsService.new(
          organization: current_organization,
          scope: validated_scope,
          patch: params[:patch]
        ).call
      end

      def validated_scope
        scope = params[:scope].to_s
        ALLOWED_SCOPES.include?(scope) ? scope : 'org'
      end

      def load_item_metadata(item_ids)
        return {} if item_ids.empty?

        # Data Dragon returns a hash keyed by item ID string (e.g. "3153").
        # The item data object itself has no 'id' field — the key IS the ID.
        item_ids_as_strings = item_ids.map(&:to_s)

        DataDragonService.new.items.each_with_object({}) do |(item_key, item_data), memo|
          next unless item_ids_as_strings.include?(item_key)

          memo[item_key.to_i] = { name: item_data['name'], description: item_data['description'] }
        end
      rescue StandardError => e
        Rails.logger.warn("[MetaIntelligence] Failed to load item metadata: #{e.message}")
        {}
      end

      def build_tier_list(analytics, item_metadata)
        analytics
          .map { |item_id, states| format_item_entry(item_id, states, item_metadata) }
          .sort_by { |entry| -entry[:total_games] }
      end

      def format_item_entry(item_id, states, item_metadata)
        total_wins  = states.values.sum { |s| s[:wins] }
        total_games = states.values.sum { |s| s[:games] }

        {
          item_id: item_id,
          name: item_metadata.dig(item_id, :name),
          total_games: total_games,
          weighted_win_rate: compute_weighted_win_rate(total_wins, total_games),
          by_game_state: states
        }
      end

      def compute_weighted_win_rate(wins, games)
        return 0.0 if games.zero?

        (wins.to_f / games * 100).round(2)
      end
    end
  end
end
