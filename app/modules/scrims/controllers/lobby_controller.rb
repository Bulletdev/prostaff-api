# frozen_string_literal: true

module Scrims
  module Controllers
    # LobbyController
    #
    # Public scrim feed — no authentication required.
    # Merges two sources:
    #   1. Scrim records with visibility: 'public'
    #   2. AvailabilityWindow records from public orgs (converted to next-occurrence slots)
    #
    # Security invariants:
    #   - Both sources require organizations.is_public = true
    #   - Windows use the .active scope (validates expires_at server-side)
    #   - No sensitive fields are serialized (no email, no subscription_plan, no internal config)
    #   - All query params validated against strict allowlists before reaching the DB
    #   - Queries are hard-capped before in-memory merge to bound memory usage
    class LobbyController < Api::V1::BaseController
      skip_before_action :authenticate_request!

      ALLOWED_GAMES   = %w[league_of_legends valorant cs2 dota2].freeze
      ALLOWED_REGIONS = %w[BR NA EUW EUNE LAN LAS OCE KR JP TR RU].freeze

      # Hard caps — prevent unbounded in-memory merge regardless of DB size
      SCRIM_CAP  = 200
      WINDOW_CAP = 100

      # GET /api/v1/scrims/lobby
      def index
        game   = ALLOWED_GAMES.include?(params[:game]) ? params[:game] : nil
        region = ALLOWED_REGIONS.include?(params[:region].to_s.upcase) ? params[:region].upcase : nil

        scrim_entries  = fetch_scrim_entries(game: game, region: region)
        window_entries = fetch_window_entries(game: game, region: region,
                                              exclude_org_ids: scrim_entries.to_set { |e| e[:organization][:id] })

        combined   = (scrim_entries + window_entries).sort_by { |e| e[:scheduled_at].to_s }
        paginated  = paginate_array(combined)

        render json: { data: { scrims: paginated[:data], pagination: paginated[:pagination] } }, status: :ok
      end

      private

      # ── Source 1: actual Scrim records ────────────────────────────────────────

      def fetch_scrim_entries(game:, region:)
        scrims = Scrim.unscoped
                      .eager_load(:organization)
                      .includes(:opponent_team)
                      .where(scrims: { visibility: 'public' })
                      .where(organizations: { is_public: true })
                      .where('scrims.scheduled_at >= ?', Time.current)
                      .order('scrims.scheduled_at ASC')
                      .limit(SCRIM_CAP)

        scrims = scrims.where(scrims: { game: game })                          if game
        scrims = scrims.where(organizations: { region: region })               if region
        scrims = filter_by_tier(scrims, params[:tier])                         if params[:tier].present?

        records = scrims.to_a
        players_by_org = load_public_players(records.map { |s| s.organization_id })
        records.map { |s| serialize_lobby_scrim(s, players_by_org) }
      end

      # ── Source 2: AvailabilityWindow records → next occurrence ───────────────

      def fetch_window_entries(game:, region:, exclude_org_ids:)
        windows = AvailabilityWindow.unscoped
                                    .active # active=true AND (expires_at IS NULL OR expires_at > now)
                                    .joins(:organization)
                                    .where(organizations: { is_public: true })
                                    .where.not(organization_id: exclude_org_ids.to_a)
                                    .includes(:organization)
                                    .limit(WINDOW_CAP)

        windows = windows.where(availability_windows: { game: game }) if game
        windows = windows.where(availability_windows: { region: region }) if region

        records = windows.to_a
        players_by_org = load_public_players(records.map { |w| w.organization_id })
        records.filter_map { |w| serialize_lobby_window(w, players_by_org) }
      end

      # ── Serializers ───────────────────────────────────────────────────────────

      def serialize_lobby_scrim(scrim, players_by_org)
        org = scrim.organization
        {
          id: scrim.id,
          scheduled_at: scrim.scheduled_at,
          scrim_type: scrim.scrim_type,
          focus_area: scrim.focus_area,
          games_planned: scrim.games_planned,
          status: scrim.status,
          source: scrim.try(:source) || 'internal',
          organization: serialize_org(org, players_by_org[org.id] || [])
        }
      end

      # Returns nil if next_occurrence cannot be computed — filter_map drops nils.
      def serialize_lobby_window(window, players_by_org)
        occurs_at = next_occurrence(window)
        return nil unless occurs_at

        org = window.organization
        {
          id: "window-#{window.id}", # namespaced to avoid collision with Scrim IDs
          scheduled_at: occurs_at,
          scrim_type: 'practice',
          focus_area: window.focus_area,
          games_planned: 3,
          status: 'open',
          source: 'availability_window',
          organization: serialize_org(org, players_by_org[org.id] || [])
        }
      end

      # Only expose fields safe for public consumption.
      # Notably absent: email, subscription_plan, is_public, internal config.
      def serialize_org(org, players)
        {
          id: org.id,
          name: org.name,
          slug: org.slug,
          region: org.region,
          tier: org.try(:tier),
          public_tagline: org.try(:public_tagline),
          discord_invite_url: org.try(:discord_invite_url),
          roster: serialize_org_roster(players)
        }
      end

      # Players are preloaded via load_public_players — no association traversal here.
      # Capped at 10 to keep the response lean.
      def serialize_org_roster(players)
        role_sort = %w[top jungle mid adc support]
        active = players.select { |p| p.status == 'active' && p.deleted_at.nil? }
        active.sort_by { |p| [role_sort.index(p.role) || 99, p.summoner_name.to_s] }
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

      # ── Helpers ───────────────────────────────────────────────────────────────

      # Loads players for the given org_ids bypassing OrganizationScoped, since
      # this is a public endpoint with no authenticated user. Returns a Hash
      # keyed by organization_id (UUID string) for O(1) lookup in serializers.
      def load_public_players(org_ids)
        return {} if org_ids.empty?

        Player.unscoped
              .where(organization_id: org_ids, deleted_at: nil)
              .select(:id, :organization_id, :summoner_name, :role,
                      :solo_queue_tier, :solo_queue_rank, :status, :deleted_at)
              .group_by(&:organization_id)
      end

      def filter_by_tier(scrims, tier)
        tier_plans = case tier
                     when 'professional' then %w[professional enterprise]
                     when 'semi_pro'     then %w[semi_pro]
                     else                     %w[free amateur]
                     end
        scrims.where(organizations: { subscription_plan: tier_plans })
      end

      # Computes the next calendar occurrence of a recurring window from now.
      # If today matches day_of_week but the window already ended, advances 7 days.
      # Returns nil on any error so the entry is safely dropped via filter_map.
      def next_occurrence(window)
        tz_name = window.timezone.presence || 'UTC'
        tz      = ActiveSupport::TimeZone[tz_name] || ActiveSupport::TimeZone['UTC']
        now     = Time.current.in_time_zone(tz)

        days_ahead = (window.day_of_week - now.wday) % 7
        days_ahead = 7 if days_ahead.zero? && now.hour >= window.end_hour

        target = now.to_date + days_ahead
        tz.local(target.year, target.month, target.day, window.start_hour, 0, 0)
      rescue ArgumentError, TZInfo::InvalidTimezone, TZInfo::AmbiguousTime
        nil
      end

      # Manual pagination for the in-memory merged array.
      def paginate_array(array)
        per_page    = params[:per_page].to_i.clamp(20, 50)
        page        = [params[:page].to_i, 1].max
        total_count = array.size
        total_pages = [(total_count.to_f / per_page).ceil, 1].max
        slice       = array.slice((page - 1) * per_page, per_page) || []

        {
          data: slice,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: total_pages,
            total_count: total_count,
            has_next_page: page < total_pages,
            has_prev_page: page > 1
          }
        }
      end
    end
  end
end
