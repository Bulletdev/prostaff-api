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

        data = champions.filter_map do |champ|
          wr = ChampionWinrateService.win_rate_for(champion: champ, patch: patch)
          next if wr.nil?

          prev_wr = if patch.present?
                      prev_patch = patch.to_s.split('.').first.to_i - 1
                      ChampionWinrateService.win_rate_for(champion: champ, patch: prev_patch.to_s)
                    end

          trend = if prev_wr.nil?       then 'stable'
                  elsif wr > prev_wr + 0.02 then 'up'
                  elsif wr < prev_wr - 0.02 then 'down'
                  else 'stable'
                  end

          tier = case wr
                 when 0.56..Float::INFINITY then 'S'
                 when 0.52...0.56           then 'A'
                 when 0.48...0.52           then 'B'
                 else                            'C'
                 end

          { name: champ, win_rate: wr.round(4), tier: tier, trend: trend, prev_win_rate: prev_wr&.round(4) }
        end

        pool_strength = data.empty? ? nil : (data.sum { |d| d[:win_rate] } / data.size).round(4)

        render_success({
          patch: patch,
          champions: data,
          pool_strength: pool_strength,
          champions_without_data: champions - data.map { |d| d[:name] }
        })
      end

      private

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
