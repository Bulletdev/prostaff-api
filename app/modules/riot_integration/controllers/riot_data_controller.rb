# frozen_string_literal: true

module RiotIntegration
  module Controllers
    class RiotDataController < Api::V1::BaseController
      skip_before_action :authenticate_request!, only: %i[champions champion_details items version]

      # GET /api/v1/riot-data/champions
      def champions
        service = DataDragonService.new
        champions = service.champion_id_map

        render_success({
                         champions: champions,
                         count: champions.count
                       })
      rescue DataDragonService::DataDragonError => e
        render_error('Failed to fetch champion data', :service_unavailable, details: e.message)
      end

      # GET /api/v1/riot-data/champions/:champion_key
      def champion_details
        service = DataDragonService.new
        champion = service.champion_by_key(params[:champion_key])

        if champion.present?
          render_success({
                           champion: champion
                         })
        else
          render_error('Champion not found', :not_found)
        end
      rescue DataDragonService::DataDragonError => e
        render_error('Failed to fetch champion details', :service_unavailable, details: e.message)
      end

      # GET /api/v1/riot-data/all-champions
      def all_champions
        service = DataDragonService.new
        champions = service.all_champions

        render_success({
                         champions: champions,
                         count: champions.count
                       })
      rescue DataDragonService::DataDragonError => e
        render_error('Failed to fetch champions', :service_unavailable, details: e.message)
      end

      # GET /api/v1/riot-data/items
      def items
        service = DataDragonService.new
        items = service.items

        render_success({
                         items: items,
                         count: items.count
                       })
      rescue DataDragonService::DataDragonError => e
        render_error('Failed to fetch items', :service_unavailable, details: e.message)
      end

      # GET /api/v1/riot-data/summoner-spells
      def summoner_spells
        service = DataDragonService.new
        spells = service.summoner_spells

        render_success({
                         summoner_spells: spells,
                         count: spells.count
                       })
      rescue DataDragonService::DataDragonError => e
        render_error('Failed to fetch summoner spells', :service_unavailable, details: e.message)
      end

      # GET /api/v1/riot-data/version
      def version
        service = DataDragonService.new
        version = service.latest_version

        render_success({
                         version: version
                       })
      rescue DataDragonService::DataDragonError => e
        render_error('Failed to fetch version', :service_unavailable, details: e.message)
      end

      # POST /api/v1/riot-data/clear-cache
      def clear_cache
        authorize :riot_data, :manage?

        service = DataDragonService.new
        service.clear_cache!

        log_user_action(
          action: 'clear_cache',
          entity_type: 'RiotData',
          entity_id: nil,
          details: { message: 'Data Dragon cache cleared' }
        )

        render_success({
                         message: 'Cache cleared successfully'
                       })
      end

      # POST /api/v1/riot-data/update-cache
      def update_cache
        authorize :riot_data, :manage?

        service = DataDragonService.new
        service.clear_cache!

        # Preload all data
        version = service.latest_version
        champions = service.champion_id_map
        items = service.items
        spells = service.summoner_spells

        log_user_action(
          action: 'update_cache',
          entity_type: 'RiotData',
          entity_id: nil,
          details: {
            version: version,
            champions_count: champions.count,
            items_count: items.count,
            spells_count: spells.count
          }
        )

        render_success({
                         message: 'Cache updated successfully',
                         version: version,
                         data: {
                           champions: champions.count,
                           items: items.count,
                           summoner_spells: spells.count
                         }
                       })
      rescue DataDragonService::DataDragonError => e
        render_error('Failed to update cache', :service_unavailable, details: e.message)
      end
    end
  end
end
