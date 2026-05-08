# frozen_string_literal: true

module AiIntelligence
  module Controllers
    # GET /api/v1/ai/champion-analytics
    #
    # Returns tier classification (S/A/B/C), win rate, and trend for each
    # champion in the supplied list, plus an aggregate pool_strength score.
    #
    # Query params:
    #   patch            [String]         e.g. "16" or "16.08" — optional
    #   team_champions[] [Array<String>]  champion names, max 20
    #
    # Requires Tier 1 (Professional) subscription — feature: predictive_analytics.
    class ChampionAnalyticsController < Api::V1::BaseController
      before_action :require_predictive_analytics_access!

      # GET /api/v1/ai/champion-analytics?patch=16&team_champions[]=Azir&team_champions[]=Jinx
      def index
        patch     = params[:patch]
        champions = Array(params[:team_champions]).first(20).map(&:strip).uniq.reject(&:blank?)

        return render json: { error: 'team_champions required' }, status: :bad_request if champions.empty?

        data          = build_champion_data(champions, patch)
        pool_strength = calculate_pool_strength(data)

        render_success({
                         patch: patch,
                         champions: data,
                         pool_strength: pool_strength,
                         champions_without_data: champions - data.map { |d| d[:name] }
                       })
      end

      private

      def build_champion_data(champions, patch)
        champions.filter_map do |champ|
          win_rate = ChampionWinrateService.win_rate_for(champion: champ, patch: patch)
          next if win_rate.nil?

          prev_win_rate = previous_patch_win_rate(champ, patch)
          { name: champ, win_rate: win_rate.round(4), tier: classify_tier(win_rate),
            trend: calculate_trend(win_rate, prev_win_rate), prev_win_rate: prev_win_rate&.round(4) }
        end
      end

      def previous_patch_win_rate(champ, patch)
        return nil unless patch.present?

        prev_patch = patch.to_s.split('.').first.to_i - 1
        ChampionWinrateService.win_rate_for(champion: champ, patch: prev_patch.to_s)
      end

      def classify_tier(win_rate)
        if win_rate >= 0.56 then 'S'
        elsif win_rate >= 0.52 then 'A'
        elsif win_rate >= 0.48 then 'B'
        else
          'C'
        end
      end

      def calculate_trend(current_rate, previous_rate)
        return 'stable' if previous_rate.nil?
        return 'up'     if current_rate > previous_rate + 0.02
        return 'down'   if current_rate < previous_rate - 0.02

        'stable'
      end

      def calculate_pool_strength(data)
        return nil if data.empty?

        (data.sum { |d| d[:win_rate] } / data.size).round(4)
      end

      def require_predictive_analytics_access!
        return if current_organization.can_access?('predictive_analytics')

        render_error(
          message: 'AI champion analytics requires Tier 1 (Professional) subscription',
          code: 'UPGRADE_REQUIRED',
          status: :forbidden
        )
      end
    end
  end
end
