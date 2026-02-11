# frozen_string_literal: true

module Api
  module V1
    module Scouting
      # Scouting Players Controller
      # Manages GLOBAL scouting targets and org-specific watchlists
      class PlayersController < Api::V1::BaseController
        before_action :set_scouting_target, only: %i[show update destroy sync]

        # GET /api/v1/scouting/players
        # Returns global scouting targets with optional watchlist filtering
        def index
          # Start with global scouting targets
          targets = ScoutingTarget.includes(:scouting_watchlists)

          # Filter by watchlist if requested
          if params[:my_watchlist] == 'true'
            targets = targets.joins(:scouting_watchlists)
                            .where(scouting_watchlists: { organization_id: current_organization.id })
          end

          # Apply global filters
          targets = apply_filters(targets)
          targets = apply_sorting(targets)

          result = paginate(targets)

          # Serialize with watchlist context
          players_data = result[:data].map do |target|
            watchlist = target.scouting_watchlists.find { |w| w.organization_id == current_organization.id }
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
            # Find or create global scouting target
            target = find_or_create_target!

            # Create watchlist entry for this organization
            watchlist = target.scouting_watchlists.create!(
              organization: current_organization,
              added_by: current_user,
              priority: watchlist_params[:priority] || 'medium',
              status: watchlist_params[:status] || 'watching',
              notes: watchlist_params[:notes],
              assigned_to_id: watchlist_params[:assigned_to_id]
            )

            log_user_action(
              action: 'create',
              entity_type: 'ScoutingWatchlist',
              entity_id: watchlist.id,
              new_values: watchlist.attributes
            )

            render_created({
                             scouting_target: JSON.parse(
                               ScoutingTargetSerializer.render(target, watchlist: watchlist)
                             )
                           }, message: 'Scouting target added successfully')
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
            # Update global target fields if provided
            if target_params.any?
              @target.update!(target_params)
            end

            # Update watchlist fields if provided
            if watchlist_params.any?
              watchlist = @target.scouting_watchlists.find_or_create_by!(organization: current_organization) do |w|
                w.added_by = current_user
              end

              old_values = watchlist.attributes.dup
              watchlist.update!(watchlist_params)

              log_user_action(
                action: 'update',
                entity_type: 'ScoutingWatchlist',
                entity_id: watchlist.id,
                old_values: old_values,
                new_values: watchlist.attributes
              )
            end

            watchlist = @target.scouting_watchlists.find_by(organization: current_organization)

            render_updated({
                             scouting_target: JSON.parse(
                               ScoutingTargetSerializer.render(@target, watchlist: watchlist)
                             )
                           })
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

          if watchlist
            watchlist.destroy

            log_user_action(
              action: 'delete',
              entity_type: 'ScoutingWatchlist',
              entity_id: watchlist.id,
              old_values: watchlist.attributes
            )

            render_deleted(message: 'Removed from watchlist')
          else
            render_error(
              message: 'Not in your watchlist',
              code: 'NOT_FOUND',
              status: :not_found
            )
          end
        end

        def sync
          # Sync functionality not yet implemented
          render_error(
            message: 'Sync functionality not yet implemented',
            code: 'NOT_IMPLEMENTED',
            status: :not_implemented
          )
        end

        private

        def find_or_create_target!
          if scouting_target_params[:riot_puuid].present?
            # Find by PUUID (global uniqueness)
            target = ScoutingTarget.find_or_initialize_by(riot_puuid: scouting_target_params[:riot_puuid])
          else
            # Create new without PUUID
            target = ScoutingTarget.new
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
          targets = targets.by_role(params[:role]) if params[:role].present?
          targets = targets.by_status(params[:status]) if params[:status].present?
          targets = targets.by_region(params[:region]) if params[:region].present?

          # Filter by watchlist fields if in watchlist mode
          if params[:my_watchlist] == 'true'
            targets = targets.where(scouting_watchlists: { priority: params[:priority] }) if params[:priority].present?
            targets = targets.where(scouting_watchlists: { assigned_to_id: params[:assigned_to_id] }) if params[:assigned_to_id].present?
          end

          targets
        end

        def apply_age_range_filter(targets)
          return targets unless params[:age_range].present? && params[:age_range].is_a?(Array)

          min_age, max_age = params[:age_range]
          min_age && max_age ? targets.where(age: min_age..max_age) : targets
        end

        def apply_rank_range_filter(targets)
          return targets unless params[:rank_range].present?

          # Rank range filtering by LP
          min_lp, max_lp = params[:rank_range]
          min_lp && max_lp ? targets.where(current_lp: min_lp..max_lp) : targets
        end

        def apply_search_filter(targets)
          return targets unless params[:search].present?

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
          params.require(:scouting_target).permit(
            :summoner_name, :real_name, :player_role, :region, :nationality,
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

        def target_params
          params.fetch(:target, {}).permit(
            :summoner_name, :real_name, :player_role, :region, :nationality,
            :age, :status, :current_team,
            :current_tier, :current_rank, :current_lp,
            :peak_tier, :peak_rank,
            :riot_puuid, :riot_summoner_id,
            :email, :phone, :discord_username, :twitter_handle,
            :notes,
            champion_pool: []
          )
        end
      end
    end
  end
end
