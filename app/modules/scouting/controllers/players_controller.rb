# frozen_string_literal: true

module Scouting
  module Controllers
    # Scouting Players Controller
    # Manages GLOBAL scouting targets and org-specific watchlists
    class PlayersController < Api::V1::BaseController
      before_action :set_scouting_target, only: %i[show update destroy sync import_to_roster]
      before_action :require_management!, only: %i[import_to_roster]

      # GET /api/v1/scouting/players
      # Returns global scouting targets with optional watchlist filtering
      def index
        # Start with global scouting targets
        targets = ScoutingTarget.all

        # Filter by watchlist if requested
        if params[:my_watchlist] == 'true'
          targets = targets.joins(:scouting_watchlists)
                           .where(scouting_watchlists: { organization_id: current_organization.id })
        end

        # Apply global filters
        targets = apply_filters(targets)
        targets = apply_sorting(targets)

        result = paginate(targets)

        # Load only this org's watchlists for the paginated targets in one query
        org_watchlists = current_organization.scouting_watchlists
                                             .where(scouting_target_id: result[:data].map(&:id))
                                             .index_by(&:scouting_target_id)

        # Serialize with watchlist context
        players_data = result[:data].map do |target|
          watchlist = org_watchlists[target.id]
          JSON.parse(ScoutingTargetSerializer.render(target, watchlist: watchlist))
        end

        render_success({
                         players: players_data,
                         total: result[:pagination][:total_count],
                         page: result[:pagination][:current_page],
                         per_page: result[:pagination][:per_page],
                         total_pages: result[:pagination][:total_pages]
                       })
      end

      # GET /api/v1/scouting/players/:id
      def show
        watchlist = @target.scouting_watchlists.find_by(organization: current_organization)

        render_success({
                         scouting_target: JSON.parse(
                           ScoutingTargetSerializer.render(@target, watchlist: watchlist)
                         )
                       })
      end

      # POST /api/v1/scouting/players
      # Creates/finds global target and adds to org watchlist
      def create
        ActiveRecord::Base.transaction do
          target = find_or_create_target!
          watchlist = create_watchlist_for(target)
          log_user_action(action: 'create', entity_type: 'ScoutingWatchlist',
                          entity_id: watchlist.id, new_values: watchlist.attributes)
          render_created(
            { scouting_target: JSON.parse(ScoutingTargetSerializer.render(target, watchlist: watchlist)) },
            message: 'Scouting target added successfully'
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        render_error(
          message: 'Failed to add scouting target',
          code: 'VALIDATION_ERROR',
          status: :unprocessable_entity,
          details: e.record.errors.as_json
        )
      end

      # PATCH /api/v1/scouting/players/:id
      # Updates global target data OR watchlist data
      def update
        ActiveRecord::Base.transaction do
          tp = target_params.to_h
          @target.update!(tp) if tp.any?
          update_watchlist_if_params_present
          render_updated(serialized_target_response)
        end
      rescue ActiveRecord::RecordInvalid => e
        render_error(
          message: 'Failed to update scouting target',
          code: 'VALIDATION_ERROR',
          status: :unprocessable_entity,
          details: e.record.errors.as_json
        )
      end

      # DELETE /api/v1/scouting/players/:id
      # Removes from org's watchlist (doesn't delete global target)
      def destroy
        watchlist = @target.scouting_watchlists.find_by(organization: current_organization)

        return render_error(message: 'Not in your watchlist', code: 'NOT_FOUND', status: :not_found) unless watchlist

        watchlist.destroy
        log_user_action(action: 'delete', entity_type: 'ScoutingWatchlist',
                        entity_id: watchlist.id, old_values: watchlist.attributes)
        render_deleted(message: 'Removed from watchlist')
      end

      # POST /api/v1/scouting/players/:id/import_to_roster
      # Hires the scouting target directly to the roster and removes them from scouting
      def import_to_roster
        result = RosterManagementService.hire_from_scouting(
          scouting_target: @target,
          organization: current_organization,
          contract_start: params[:contract_start].present? ? Date.parse(params[:contract_start]) : nil,
          contract_end: params[:contract_end].present? ? Date.parse(params[:contract_end]) : nil,
          salary: params[:salary]&.to_d,
          jersey_number: params[:jersey_number]&.to_i,
          line: params[:line],
          current_user: current_user
        )

        if result[:success]
          render_created(
            { player: PlayerSerializer.render_as_hash(result[:player]) },
            message: result[:message]
          )
        else
          render_error(message: result[:error], code: result[:code], status: :unprocessable_entity)
        end
      rescue ArgumentError
        render_error(message: 'Invalid date format. Use YYYY-MM-DD', code: 'INVALID_DATE_FORMAT',
                     status: :unprocessable_entity)
      end

      def sync
        unless @target.riot_puuid.present?
          return render_error(
            message: 'Cannot sync player without Riot PUUID',
            code: 'MISSING_PUUID',
            status: :unprocessable_entity
          )
        end

        perform_sync_from_riot
      rescue RiotApiService::NotFoundError
        render_error(message: 'Player not found in Riot API', code: 'PLAYER_NOT_FOUND', status: :not_found)
      rescue RiotApiService::RiotApiError => e
        render_error(message: "Failed to sync player data: #{e.message}", code: 'RIOT_API_ERROR',
                     status: :service_unavailable)
      end

      # Ordered list of tiers from lowest to highest for peak comparison.
      TIER_ORDER = %w[IRON BRONZE SILVER GOLD PLATINUM EMERALD DIAMOND MASTER GRANDMASTER CHALLENGER].freeze

      private

      def require_management!
        return if %w[admin owner].include?(current_user.role)

        render_error(
          message: 'Only owners and admins can import players to the roster',
          code: 'FORBIDDEN',
          status: :forbidden
        )
      end

      def create_watchlist_for(target)
        target.scouting_watchlists.create!(
          organization: current_organization,
          added_by: current_user,
          priority: watchlist_params[:priority] || 'medium',
          status: watchlist_params[:status] || 'watching',
          notes: watchlist_params[:notes],
          assigned_to_id: watchlist_params[:assigned_to_id]
        )
      end

      def update_watchlist_if_params_present
        wp = watchlist_params.to_h
        wp = scouting_target_watchlist_params.to_h if wp.empty?
        return if wp.empty?

        watchlist = @target.scouting_watchlists.find_or_create_by!(organization: current_organization) do |w|
          w.added_by = current_user
        end
        old_values = watchlist.attributes.dup
        watchlist.update!(wp)
        log_user_action(action: 'update', entity_type: 'ScoutingWatchlist',
                        entity_id: watchlist.id, old_values: old_values, new_values: watchlist.attributes)
      end

      def serialized_target_response
        watchlist = @target.scouting_watchlists.find_by(organization: current_organization)
        { scouting_target: JSON.parse(ScoutingTargetSerializer.render(@target, watchlist: watchlist)) }
      end

      def perform_sync_from_riot
        riot_service = RiotApiService.new
        region = @target.region

        # Get account info for name (Riot API no longer returns name in summoner endpoint)
        account_data = riot_service.get_account_by_puuid(puuid: @target.riot_puuid, region: region)
        riot_service.get_summoner_by_puuid(puuid: @target.riot_puuid, region: region)
        # Use PUUID to get league entries (Riot API no longer returns summoner_id)
        league_data = riot_service.get_league_entries_by_puuid(puuid: @target.riot_puuid, region: region)
        mastery_data = riot_service.get_champion_mastery(puuid: @target.riot_puuid, region: region)

        pool = extract_champion_pool(mastery_data)
        perf = PerformanceAggregator.new(riot_service: riot_service)
                                    .call(puuid: @target.riot_puuid, region: region) ||
               @target.recent_performance || {}
        tier = league_data[:solo_queue]&.dig(:tier) || @target.current_tier
        lp   = league_data[:solo_queue]&.dig(:lp)
        strengths = derive_strengths(perf, pool, @target.role, tier)
        weaknesses = derive_weaknesses(perf, pool, @target.role, tier)

        new_peak_tier, new_peak_rank = resolve_peak(
          current_tier: tier,
          current_lp: lp,
          stored_peak_tier: @target.peak_tier,
          stored_peak_rank: @target.peak_rank
        )

        @target.update!(
          summoner_name: "#{account_data[:game_name]}##{account_data[:tag_line]}",
          current_tier: tier,
          current_rank: league_data[:solo_queue]&.dig(:rank),
          current_lp: lp,
          peak_tier: new_peak_tier,
          peak_rank: new_peak_rank,
          champion_pool: pool,
          recent_performance: perf,
          performance_trend: calculate_performance_trend(league_data),
          strengths: strengths,
          weaknesses: weaknesses,
          last_api_sync_at: Time.current
        )

        SeasonHistoryUpdater.call(target: @target, league_data: league_data)

        watchlist = @target.scouting_watchlists.find_by(organization: current_organization)
        render_success(
          { scouting_target: JSON.parse(ScoutingTargetSerializer.render(@target, watchlist: watchlist)) },
          message: 'Player data synced successfully'
        )
      end

      def find_or_create_target!
        target = if scouting_target_params[:riot_puuid].present?
                   # Find by PUUID (global uniqueness)
                   ScoutingTarget.find_or_initialize_by(riot_puuid: scouting_target_params[:riot_puuid])
                 else
                   # Create new without PUUID
                   ScoutingTarget.new
                 end

        target.assign_attributes(scouting_target_params)
        target.save!
        target
      end

      def apply_filters(targets)
        targets = apply_basic_filters(targets)
        targets = apply_age_range_filter(targets)
        targets = apply_rank_range_filter(targets)
        apply_search_filter(targets)
      end

      def apply_basic_filters(targets)
        # role param is comma-separated lowercase: "mid,top" → ["mid", "top"]
        if params[:role].present?
          roles = params[:role].split(',').map(&:strip).reject(&:blank?)
          targets = targets.by_role(roles) if roles.any?
        end
        if params[:status].present?
          targets = targets.by_status(params[:status])
        else
          targets = targets.where.not(status: 'signed')
        end
        targets = targets.by_region(params[:region]) if params[:region].present?

        # Filter by watchlist fields if in watchlist mode
        if params[:my_watchlist] == 'true'
          targets = targets.where(scouting_watchlists: { priority: params[:priority] }) if params[:priority].present?
          if params[:assigned_to_id].present?
            targets = targets.where(scouting_watchlists: { assigned_to_id: params[:assigned_to_id] })
          end
        end

        targets
      end

      def apply_age_range_filter(targets)
        min_age = params[:age_min].presence&.to_i
        max_age = params[:age_max].presence&.to_i
        return targets unless min_age && max_age

        targets.where(age: min_age..max_age)
      end

      def apply_rank_range_filter(targets)
        min_lp = params[:lp_min].presence&.to_i
        max_lp = params[:lp_max].presence&.to_i
        return targets unless min_lp || max_lp

        targets = targets.where('current_lp >= ?', min_lp) if min_lp
        targets = targets.where('current_lp <= ?', max_lp) if max_lp
        targets
      end

      def apply_search_filter(targets)
        return targets unless params[:search].present?

        meili = SearchService.scope(ScoutingTarget, query: params[:search])
        return meili if meili

        # Fallback to SQL when Meilisearch is unavailable
        search_term = "%#{params[:search]}%"
        targets.where('summoner_name ILIKE ? OR real_name ILIKE ?', search_term, search_term)
      end

      def apply_sorting(targets)
        sort_by, sort_order = validate_sort_params

        case sort_by
        when 'rank'
          apply_rank_sorting(targets, sort_order)
        when 'winrate'
          apply_winrate_sorting(targets, sort_order)
        else
          targets.order(sort_by => sort_order)
        end
      end

      def validate_sort_params
        allowed_sort_fields = %w[created_at updated_at summoner_name current_tier priority status role region age rank
                                 winrate]
        allowed_sort_orders = %w[asc desc]

        sort_by = allowed_sort_fields.include?(params[:sort_by]) ? params[:sort_by] : 'created_at'
        sort_order = if allowed_sort_orders.include?(params[:sort_order]&.downcase)
                       params[:sort_order].downcase
                     else
                       'desc'
                     end

        [sort_by, sort_order]
      end

      def apply_rank_sorting(targets, sort_order)
        column = ScoutingTarget.arel_table[:current_lp]
        order_clause = sort_order == 'asc' ? column.asc.nulls_last : column.desc.nulls_last
        targets.order(order_clause)
      end

      def apply_winrate_sorting(targets, sort_order)
        column = ScoutingTarget.arel_table[:performance_trend]
        order_clause = sort_order == 'asc' ? column.asc.nulls_last : column.desc.nulls_last
        targets.order(order_clause)
      end

      def set_scouting_target
        @target = ScoutingTarget.find_by!(id: params[:id])
      end

      def scouting_target_params
        # :role is the LoL in-game position (top/jungle/mid/adc/support), not an authorization role.
        # nosemgrep: ruby.lang.security.model-attr-accessible.model-attr-accessible
        params.require(:scouting_target).permit( # NOSONAR
          :summoner_name, :real_name, :role, :region, :nationality,
          :age, :status, :current_team,
          :current_tier, :current_rank, :current_lp,
          :peak_tier, :peak_rank,
          :riot_puuid, :riot_summoner_id,
          :email, :phone, :discord_username, :twitter_handle,
          :notes, :availability, :salary_expectations,
          :performance_trend,
          champion_pool: []
        )
      end

      def watchlist_params
        params.fetch(:watchlist, {}).permit(
          :priority, :status, :notes, :assigned_to_id
        )
      end

      def scouting_target_watchlist_params
        params.fetch(:scouting_target, {}).permit(
          :priority, :status, :notes, :assigned_to_id
        )
      end

      def target_params
        # :role is the LoL in-game position (top/jungle/mid/adc/support), not an authorization role.
        params.fetch(:target, {}).permit( # nosemgrep: ruby.lang.security.model-attr-accessible.model-attr-accessible
          :summoner_name, :real_name, :role, :region, :nationality,
          :age, :status, :current_team,
          :current_tier, :current_rank, :current_lp,
          :peak_tier, :peak_rank,
          :riot_puuid, :riot_summoner_id,
          :email, :phone, :discord_username, :twitter_handle,
          :notes,
          champion_pool: []
        )
      end

      # Returns [peak_tier, peak_rank] — keeps the stored peak unless the current rank is provably higher.
      # Master+ has no divisions so LP is the tiebreaker; below Master, roman numeral rank I > II > III > IV.
      def resolve_peak(current_tier:, current_lp:, stored_peak_tier:, stored_peak_rank:)
        return [current_tier, nil] if stored_peak_tier.blank?

        current_idx = TIER_ORDER.index(current_tier&.upcase) || 0
        stored_idx  = TIER_ORDER.index(stored_peak_tier&.upcase) || 0

        return [stored_peak_tier, stored_peak_rank] if current_idx < stored_idx

        if current_idx == stored_idx
          # Same tier — for Master+ LP is the signal but we don't have stored peak LP here,
          # so leave peak unchanged (it was set by a prior sync at equal or higher LP)
          return [stored_peak_tier, stored_peak_rank]
        end

        # current_idx > stored_idx — new tier is strictly higher
        [current_tier, nil]
      end

      # Thresholds calibrated by tier. Mirrors RosterManagementService#tier_thresholds.
      # JSONB from DB returns string keys, so we use with_indifferent_access throughout.
      def tier_thresholds(tier)
        case tier&.upcase
        when 'CHALLENGER', 'GRANDMASTER', 'MASTER'
          { wr_strength: 53, wr_weakness: 49, kda_strength: 4.5, kda_weakness: 3.0,
            cs_strength: 9.0, cs_weakness: 7.5, vision_strength: 45, vision_weakness: 28 }
        when 'DIAMOND', 'EMERALD'
          { wr_strength: 54, wr_weakness: 47, kda_strength: 4.0, kda_weakness: 2.5,
            cs_strength: 8.5, cs_weakness: 7.0, vision_strength: 42, vision_weakness: 24 }
        else
          { wr_strength: 55, wr_weakness: 45, kda_strength: 3.5, kda_weakness: 2.0,
            cs_strength: 8.0, cs_weakness: 6.0, vision_strength: 40, vision_weakness: 20 }
        end
      end

      def derive_strengths(perf, pool, role, tier = nil)
        return [] if perf.blank?

        p = perf.with_indifferent_access
        t = tier_thresholds(tier)
        strengths = []
        strengths << 'Consistency'         if p[:win_rate].to_f >= t[:wr_strength]
        strengths << 'Mechanical skill'    if p[:avg_kda].to_f >= t[:kda_strength]
        strengths << 'CS discipline'       if non_support?(role) && p[:avg_cs_per_min].to_f >= t[:cs_strength]
        strengths << 'Map awareness'       if vision_role?(role) && p[:avg_vision_score].to_f >= t[:vision_strength]
        strengths << 'Team fighting'       if p[:avg_kill_participation].to_f >= 65.0
        strengths << 'Champion pool depth' if pool.size >= 6
        strengths
      end

      def derive_weaknesses(perf, pool, role, tier = nil)
        return [] if perf.blank?

        p = perf.with_indifferent_access
        t = tier_thresholds(tier)
        weaknesses = []
        weaknesses << 'Inconsistent performance' if p[:games_played].to_i >= 10 &&
                                                    p[:win_rate].to_f < t[:wr_weakness]
        weaknesses << 'Death management'         if p[:avg_kda].to_f.positive? &&
                                                    p[:avg_kda].to_f < t[:kda_weakness]
        weaknesses << 'CS discipline'            if non_support?(role) &&
                                                    p[:avg_cs_per_min].to_f.positive? &&
                                                    p[:avg_cs_per_min].to_f < t[:cs_weakness]
        weaknesses << 'Vision control'           if vision_role?(role) &&
                                                    p[:avg_vision_score].to_f.positive? &&
                                                    p[:avg_vision_score].to_f < t[:vision_weakness]
        weaknesses << 'Limited champion pool'    if pool.size < 3
        weaknesses
      end

      def non_support?(role)
        role.to_s != 'support'
      end

      def vision_role?(role)
        %w[support jungle].include?(role.to_s)
      end

      # Extract top champions from mastery data using DataDragonService for full champion coverage.
      # Falls back to "Champion_<id>" only when Data Dragon is unreachable.
      def extract_champion_pool(mastery_data)
        return [] if mastery_data.blank?

        id_map = DataDragonService.new.champion_id_map

        mastery_data.first(10).filter_map do |mastery|
          id_map[mastery[:champion_id].to_i]
        end
      end

      # Calculate performance trend based on win/loss ratio
      def calculate_performance_trend(league_data)
        solo_queue = league_data[:solo_queue]
        return 'stable' unless solo_queue

        wins = solo_queue[:wins] || 0
        losses = solo_queue[:losses] || 0
        total_games = wins + losses

        return 'stable' if total_games.zero?

        win_rate = (wins.to_f / total_games * 100).round(2)

        case win_rate
        when 0..45 then 'declining'
        when 45..52 then 'stable'
        else 'improving'
        end
      end
    end
  end
end
