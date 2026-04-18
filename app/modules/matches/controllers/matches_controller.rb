# frozen_string_literal: true

module Matches
  module Controllers
    # API controller for organization-scoped matches.
    # Supports CRUD operations, filtering, sorting, and per-match player stats.
    class MatchesController < Api::V1::BaseController
      include Analytics::Concerns::AnalyticsCalculations
      include ParameterValidation
      include Cacheable

      before_action :set_match, only: %i[show update destroy stats]

      def index
        matches = organization_scoped(Match).includes(:player_match_stats, :players)
        matches = apply_match_filters(matches)
        matches = apply_match_sorting(matches)

        result = paginate(matches)

        data = cache_response('matches', expires_in: 5.minutes) do
          {
            matches: MatchSerializer.render_as_hash(result[:data]),
            pagination: result[:pagination],
            summary: calculate_matches_summary(matches)
          }
        end

        render_success(data)
      end

      def show
        data = cache_response("matches/#{@match.id}", expires_in: 5.minutes) do
          match_data = MatchSerializer.render_as_hash(@match)
          player_stats = PlayerMatchStatSerializer.render_as_hash(
            @match.player_match_stats.includes(:player)
          )

          {
            match: match_data,
            player_stats: player_stats,
            team_composition: @match.team_composition,
            mvp: @match.mvp_player ? PlayerSerializer.render_as_hash(@match.mvp_player) : nil
          }
        end

        render_success(data)
      end

      def create
        match = organization_scoped(Match).new(match_params)
        match.organization = current_organization

        if match.save
          log_user_action(
            action: 'create',
            entity_type: 'Match',
            entity_id: match.id,
            new_values: match.attributes
          )

          render_created({
                           match: MatchSerializer.render_as_hash(match)
                         }, message: 'Match created successfully')
        else
          render_error(
            message: 'Failed to create match',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: match.errors.as_json
          )
        end
      end

      def update
        old_values = @match.attributes.dup

        if @match.update(match_params)
          log_user_action(
            action: 'update',
            entity_type: 'Match',
            entity_id: @match.id,
            old_values: old_values,
            new_values: @match.attributes
          )

          render_updated({
                           match: MatchSerializer.render_as_hash(@match)
                         })
        else
          render_error(
            message: 'Failed to update match',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: @match.errors.as_json
          )
        end
      end

      def destroy
        if @match.destroy
          log_user_action(
            action: 'delete',
            entity_type: 'Match',
            entity_id: @match.id,
            old_values: @match.attributes
          )

          render_deleted(message: 'Match deleted successfully')
        else
          render_error(
            message: 'Failed to delete match',
            code: 'DELETE_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      def stats
        stats = @match.player_match_stats.includes(:player)

        stats_data = {
          match: MatchSerializer.render_as_hash(@match),
          team_stats: calculate_team_stats(stats),
          player_stats: stats.map do |stat|
            player_data = PlayerMatchStatSerializer.render_as_hash(stat)
            player_data[:player] = PlayerSerializer.render_as_hash(stat.player)
            player_data
          end,
          comparison: {
            total_gold: stats.sum(:gold_earned),
            total_damage: stats.sum(:damage_dealt_total),
            total_vision_score: stats.sum(:vision_score),
            avg_kda: calculate_avg_kda(stats)
          }
        }

        render_success(stats_data)
      end

      def import
        player_id    = validate_required_param!(:player_id)
        count        = integer_param(:count, default: 20, min: 1, max: 100)
        force_update = params[:force_update].in?([true, 'true', '1'])

        player = organization_scoped(Player).find(player_id)

        unless player.riot_puuid.present?
          return render_error(
            message: 'Player does not have a Riot PUUID. Please sync player from Riot first.',
            code: 'MISSING_PUUID',
            status: :bad_request
          )
        end

        result = ImportMatchesService.new(
          player: player,
          organization: current_organization,
          count: count,
          force_update: force_update
        ).call

        render_success(result, message: 'Matches import started successfully')
      rescue RiotApiService::RiotApiError => e
        render_error(
          message: "Riot API error: #{e.message}",
          code: 'RIOT_API_ERROR',
          status: :service_unavailable
        )
      end

      private

      def apply_match_filters(matches)
        matches = apply_basic_match_filters(matches)
        matches = apply_date_filters_to_matches(matches)
        matches = apply_opponent_filter(matches)
        apply_tournament_filter(matches)
      end

      def apply_basic_match_filters(matches)
        matches = matches.by_type(params[:match_type]) if params[:match_type].present?
        matches = matches.victories if params[:result] == 'victory'
        matches = matches.defeats if params[:result] == 'defeat'
        matches
      end

      def apply_date_filters_to_matches(matches)
        if params[:start_date].present? && params[:end_date].present?
          matches.in_date_range(params[:start_date], params[:end_date])
        elsif params[:days].present?
          matches.recent(params[:days].to_i)
        else
          matches
        end
      end

      def apply_opponent_filter(matches)
        params[:opponent].present? ? matches.with_opponent(params[:opponent]) : matches
      end

      def apply_tournament_filter(matches)
        return matches unless params[:tournament].present?

        matches.where('tournament_name ILIKE ?', "%#{params[:tournament]}%")
      end

      def apply_match_sorting(matches)
        allowed_sort_fields = %w[game_start game_duration match_type victory created_at]
        allowed_sort_orders = %w[asc desc]

        sort_by = allowed_sort_fields.include?(params[:sort_by]) ? params[:sort_by] : 'game_start'
        sort_order = allowed_sort_orders.include?(params[:sort_order]) ? params[:sort_order] : 'desc'

        matches.order(sort_by => sort_order)
      end

      def set_match
        @match = organization_scoped(Match).find(params[:id])
      end

      def match_params
        params.require(:match).permit(
          :match_type, :game_start, :game_end, :game_duration,
          :riot_match_id, :patch_version, :tournament_name, :stage,
          :opponent_name, :opponent_tag, :victory,
          :our_side, :our_score, :opponent_score,
          :first_blood, :first_tower, :first_baron, :first_dragon,
          :total_kills, :total_deaths, :total_assists, :total_gold,
          :vod_url, :replay_file_url, :notes
        )
      end

      def calculate_matches_summary(matches)
        {
          total: matches.count,
          victories: matches.victories.count,
          defeats: matches.defeats.count,
          win_rate: calculate_win_rate(matches),
          by_type: matches.unscope(:order).group(:match_type).count,
          avg_duration: matches.average(:game_duration)&.round(0)
        }
      end

      def calculate_team_stats(stats)
        {
          total_kills: stats.sum(:kills),
          total_deaths: stats.sum(:deaths),
          total_assists: stats.sum(:assists),
          total_gold: stats.sum(:gold_earned),
          total_damage: stats.sum(:damage_dealt_total),
          total_cs: stats.sum(:cs),
          total_vision_score: stats.sum(:vision_score)
        }
      end
    end
  end
end
