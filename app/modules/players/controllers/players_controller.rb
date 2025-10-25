# frozen_string_literal: true

module Players
  module Controllers
    # Controller for managing players within an organization
    # Business logic extracted to Services for better organization
    class PlayersController < Api::V1::BaseController
      before_action :set_player, only: %i[show update destroy stats matches sync_from_riot]

      # GET /api/v1/players
      def index
        players = organization_scoped(Player).includes(:champion_pools)

        players = players.by_role(params[:role]) if params[:role].present?
        players = players.by_status(params[:status]) if params[:status].present?

        if params[:search].present?
          search_term = "%#{params[:search]}%"
          players = players.where('summoner_name ILIKE ? OR real_name ILIKE ?', search_term, search_term)
        end

        result = paginate(players.ordered_by_role.order(:summoner_name))

        render_success({
                         players: PlayerSerializer.render_as_hash(result[:data]),
                         pagination: result[:pagination]
                       })
      end

      # GET /api/v1/players/:id
      def show
        render_success({
                         player: PlayerSerializer.render_as_hash(@player)
                       })
      end

      # POST /api/v1/players
      def create
        player = organization_scoped(Player).new(player_params)
        player.organization = current_organization

        if player.save
          log_user_action(
            action: 'create',
            entity_type: 'Player',
            entity_id: player.id,
            new_values: player.attributes
          )

          render_created({
                           player: PlayerSerializer.render_as_hash(player)
                         }, message: 'Player created successfully')
        else
          render_error(
            message: 'Failed to create player',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: player.errors.as_json
          )
        end
      end

      # PATCH/PUT /api/v1/players/:id
      def update
        old_values = @player.attributes.dup

        if @player.update(player_params)
          log_user_action(
            action: 'update',
            entity_type: 'Player',
            entity_id: @player.id,
            old_values: old_values,
            new_values: @player.attributes
          )

          render_updated({
                           player: PlayerSerializer.render_as_hash(@player)
                         })
        else
          render_error(
            message: 'Failed to update player',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: @player.errors.as_json
          )
        end
      end

      # DELETE /api/v1/players/:id
      def destroy
        if @player.destroy
          log_user_action(
            action: 'delete',
            entity_type: 'Player',
            entity_id: @player.id,
            old_values: @player.attributes
          )

          render_deleted(message: 'Player deleted successfully')
        else
          render_error(
            message: 'Failed to delete player',
            code: 'DELETE_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      # GET /api/v1/players/:id/stats
      def stats
        stats_service = Players::Services::StatsService.new(@player)
        stats_data = stats_service.calculate_stats

        render_success({
                         player: PlayerSerializer.render_as_hash(stats_data[:player]),
                         overall: stats_data[:overall],
                         recent_form: stats_data[:recent_form],
                         champion_pool: ChampionPoolSerializer.render_as_hash(stats_data[:champion_pool]),
                         performance_by_role: stats_data[:performance_by_role]
                       })
      end

      # GET /api/v1/players/:id/matches
      def matches
        matches = @player.matches
                         .includes(:player_match_stats)
                         .order(game_start: :desc)

        if params[:start_date].present? && params[:end_date].present?
          matches = matches.in_date_range(params[:start_date], params[:end_date])
        end

        result = paginate(matches)

        matches_with_stats = result[:data].map do |match|
          player_stat = match.player_match_stats.find_by(player: @player)
          {
            match: MatchSerializer.render_as_hash(match),
            player_stats: player_stat ? PlayerMatchStatSerializer.render_as_hash(player_stat) : nil
          }
        end

        render_success({
                         matches: matches_with_stats,
                         pagination: result[:pagination]
                       })
      end

      # POST /api/v1/players/import
      def import
        summoner_name = params[:summoner_name]&.strip
        role = params[:role]
        region = params[:region] || 'br1'

        # Validations
        return unless validate_import_params(summoner_name, role)
        return unless validate_player_uniqueness(summoner_name)

        # Import from Riot API
        result = import_player_from_riot(summoner_name, role, region)

        # Handle result
        result[:success] ? handle_import_success(result) : handle_import_error(result)
      end

      # POST /api/v1/players/:id/sync_from_riot
      def sync_from_riot
        service = Players::Services::RiotSyncService.new(@player, region: params[:region])
        result = service.sync

        if result[:success]
          log_user_action(
            action: 'sync_riot',
            entity_type: 'Player',
            entity_id: @player.id,
            new_values: @player.attributes
          )

          render_success({
                           player: PlayerSerializer.render_as_hash(@player.reload),
                           message: 'Player synced successfully from Riot API'
                         })
        else
          render_error(
            message: "Failed to sync with Riot API: #{result[:error]}",
            code: result[:code] || 'SYNC_ERROR',
            status: :service_unavailable
          )
        end
      end

      # GET /api/v1/players/search_riot_id
      def search_riot_id
        summoner_name = params[:summoner_name]&.strip
        region = params[:region] || 'br1'

        unless summoner_name.present?
          return render_error(
            message: 'Summoner name is required',
            code: 'MISSING_PARAMETERS',
            status: :unprocessable_entity
          )
        end

        result = Players::Services::RiotSyncService.search_riot_id(summoner_name, region: region)

        if result[:success] && result[:found]
          render_success(result.except(:success))
        elsif result[:success] && !result[:found]
          render_error(
            message: result[:error],
            code: 'PLAYER_NOT_FOUND',
            status: :not_found,
            details: {
              game_name: result[:game_name],
              tried_tags: result[:tried_tags],
              hint: 'Please verify the exact Riot ID in the League client (Settings > Account > Riot ID)'
            }
          )
        else
          render_error(
            message: result[:error],
            code: result[:code] || 'SEARCH_ERROR',
            status: :service_unavailable
          )
        end
      end

      # POST /api/v1/players/bulk_sync
      def bulk_sync
        status = params[:status] || 'active'

        players = organization_scoped(Player).where(status: status)

        if players.empty?
          return render_error(
            message: "No #{status} players found to sync",
            code: 'NO_PLAYERS_FOUND',
            status: :not_found
          )
        end

        riot_api_key = ENV['RIOT_API_KEY']
        unless riot_api_key.present?
          return render_error(
            message: 'Riot API key not configured',
            code: 'RIOT_API_NOT_CONFIGURED',
            status: :service_unavailable
          )
        end

        players.update_all(sync_status: 'syncing')

        players.each do |player|
          SyncPlayerFromRiotJob.perform_later(player.id)
        end

        render_success({
                         message: "#{players.count} players queued for sync",
                         players_count: players.count
                       })
      end

      private

      def set_player
        @player = organization_scoped(Player).find(params[:id])
      end

      def player_params
        # :role refers to in-game position (top/jungle/mid/adc/support), not user role
        # nosemgrep
        params.require(:player).permit(
          :summoner_name, :real_name, :role, :region, :status, :jersey_number,
          :birth_date, :country, :nationality,
          :contract_start_date, :contract_end_date,
          :solo_queue_tier, :solo_queue_rank, :solo_queue_lp,
          :solo_queue_wins, :solo_queue_losses,
          :flex_queue_tier, :flex_queue_rank, :flex_queue_lp,
          :peak_tier, :peak_rank, :peak_season,
          :riot_puuid, :riot_summoner_id,
          :twitter_handle, :twitch_channel, :instagram_handle,
          :notes
        )
      end

      # Validate import parameters
      def validate_import_params(summoner_name, role)
        unless summoner_name.present? && role.present?
          render_error(
            message: 'Summoner name and role are required',
            code: 'MISSING_PARAMETERS',
            status: :unprocessable_entity,
            details: {
              hint: 'Format: "GameName#TAG" or "GameName-TAG" (e.g., "Faker#KR1" or "Faker-KR1")'
            }
          )
          return false
        end

        unless %w[top jungle mid adc support].include?(role)
          render_error(
            message: 'Invalid role',
            code: 'INVALID_ROLE',
            status: :unprocessable_entity
          )
          return false
        end

        true
      end

      # Check if player already exists
      def validate_player_uniqueness(summoner_name)
        existing_player = organization_scoped(Player).find_by(summoner_name: summoner_name)
        return true unless existing_player

        render_error(
          message: 'Player already exists in your organization',
          code: 'PLAYER_EXISTS',
          status: :unprocessable_entity
        )
        false
      end

      # Import player from Riot API
      def import_player_from_riot(summoner_name, role, region)
        Players::Services::RiotSyncService.import(
          summoner_name: summoner_name,
          role: role,
          region: region,
          organization: current_organization
        )
      end

      # Handle successful import
      def handle_import_success(result)
        log_user_action(
          action: 'import_riot',
          entity_type: 'Player',
          entity_id: result[:player].id,
          new_values: result[:player].attributes
        )

        render_created({
                         player: PlayerSerializer.render_as_hash(result[:player]),
                         message: "Player #{result[:summoner_name]} imported successfully from Riot API"
                       })
      end

      # Handle import error
      def handle_import_error(result)
        # Determine appropriate HTTP status based on error code
        status = case result[:code]
                 when 'PLAYER_NOT_FOUND', 'INVALID_FORMAT'
                   :not_found
                 when 'PLAYER_BELONGS_TO_OTHER_ORGANIZATION'
                   :forbidden
                 when 'RIOT_API_ERROR'
                   # Check if it's a server error (5xx) or rate limit
                   result[:status_code] && result[:status_code] >= 500 ? :bad_gateway : :service_unavailable
                 else
                   :service_unavailable
                 end

        render_error(
          message: result[:error] || "Failed to import from Riot API",
          code: result[:code] || 'IMPORT_ERROR',
          status: status
        )
      end
    end
  end
end
