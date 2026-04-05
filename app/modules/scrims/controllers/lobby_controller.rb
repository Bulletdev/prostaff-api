# frozen_string_literal: true

module Scrims
  module Controllers
    # LobbyController
    #
    # Public scrim feed — no authentication required.
    # Only exposes scrims from organizations that opted into public visibility.
    class LobbyController < Api::V1::BaseController
      skip_before_action :authenticate_request!

      ALLOWED_GAMES = %w[league_of_legends valorant cs2 dota2].freeze
      ALLOWED_REGIONS = %w[BR NA EUW EUNE LAN LAS OCE KR JP TR RU].freeze

      # GET /api/v1/scrims/lobby
      # Public feed of open scrims — no auth required
      def index
        scrims = Scrim.unscoped
                      .eager_load(:organization)
                      .includes(:opponent_team, organization: :players)
                      .where(scrims: { visibility: 'public' })
                      .where(organizations: { is_public: true })
                      .where('scrims.scheduled_at >= ?', Time.current)
                      .order('scrims.scheduled_at ASC')

        scrims = scrims.where(game: params[:game]) if params[:game].present? && ALLOWED_GAMES.include?(params[:game])

        if params[:region].present? && ALLOWED_REGIONS.include?(params[:region].upcase)
          scrims = scrims.where(organizations: { region: params[:region].upcase })
        end

        scrims = filter_by_tier(scrims, params[:tier]) if params[:tier].present?

        result = paginate(scrims)

        render json: {
          data: {
            scrims: result[:data].map { |s| serialize_lobby_scrim(s) },
            pagination: result[:pagination]
          }
        }, status: :ok
      end

      private

      def filter_by_tier(scrims, tier)
        tier_plans = case tier
                     when 'professional' then %w[professional enterprise]
                     when 'semi_pro'     then %w[semi_pro]
                     else                     %w[free amateur]
                     end
        scrims.where(organizations: { subscription_plan: tier_plans })
      end

      def serialize_lobby_scrim(scrim)
        org = scrim.organization
        {
          id: scrim.id,
          scheduled_at: scrim.scheduled_at,
          scrim_type: scrim.scrim_type,
          focus_area: scrim.focus_area,
          games_planned: scrim.games_planned,
          status: scrim.status,
          source: scrim.try(:source) || 'internal',
          organization: {
            id: org.id,
            name: org.name,
            slug: org.slug,
            region: org.region,
            tier: org.try(:tier),
            public_tagline: org.try(:public_tagline),
            discord_invite_url: org.try(:discord_invite_url),
            roster: serialize_org_roster(org)
          }
        }
      end

      # Returns the org's active players sorted by role, already preloaded via includes.
      # Capped at 10 to keep the response lean.
      def serialize_org_roster(org)
        role_sort = %w[top jungle mid adc support]
        players = org.players.select(&:active?)
        players.sort_by { |p| [role_sort.index(p.role) || 99, p.summoner_name] }
               .first(10)
               .map do |p|
          {
            summoner_name: p.summoner_name,
            role: p.role,
            tier: p.solo_queue_tier,
            tier_rank: p.solo_queue_rank
          }
        end
      end
    end
  end
end
