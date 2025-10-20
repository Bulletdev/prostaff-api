module Api
  module V1
    module Competitive
      class ProMatchesController < Api::V1::BaseController
        before_action :set_pandascore_service

        # GET /api/v1/competitive/pro-matches
        # List recent professional matches from database
        def index
          matches = current_organization.competitive_matches
            .ordered_by_date
            .page(params[:page] || 1)
            .per(params[:per_page] || 20)

          # Apply filters
          matches = apply_filters(matches)

          render json: {
            message: 'Professional matches retrieved successfully',
            data: {
              matches: ::Competitive::Serializers::ProMatchSerializer.render_as_hash(matches),
              pagination: pagination_meta(matches)
            }
          }
        rescue StandardError => e
          Rails.logger.error "[ProMatches] Error in index: #{e.message}"
          render json: {
            error: {
              code: 'PRO_MATCHES_ERROR',
              message: 'Failed to retrieve matches',
              details: e.message
            }
          }, status: :internal_server_error
        end

        # GET /api/v1/competitive/pro-matches/:id
        # Get details of a specific professional match
        def show
          match = current_organization.competitive_matches.find(params[:id])

          render json: {
            message: 'Match details retrieved successfully',
            data: {
              match: ::Competitive::Serializers::ProMatchSerializer.render_as_hash(match)
            }
          }
        rescue ActiveRecord::RecordNotFound
          render json: {
            error: {
              code: 'MATCH_NOT_FOUND',
              message: 'Professional match not found'
            }
          }, status: :not_found
        end

        # GET /api/v1/competitive/pro-matches/upcoming
        # Fetch upcoming matches from PandaScore API
        def upcoming
          league = params[:league]
          per_page = params[:per_page]&.to_i || 10

          matches = @pandascore_service.fetch_upcoming_matches(
            league: league,
            per_page: per_page
          )

          render json: {
            message: 'Upcoming matches retrieved successfully',
            data: {
              matches: matches,
              source: 'pandascore',
              cached: true
            }
          }
        rescue ::Competitive::Services::PandascoreService::PandascoreError => e
          render json: {
            error: {
              code: 'PANDASCORE_ERROR',
              message: e.message
            }
          }, status: :service_unavailable
        end

        # GET /api/v1/competitive/pro-matches/past
        # Fetch past matches from PandaScore API
        def past
          league = params[:league]
          per_page = params[:per_page]&.to_i || 20

          matches = @pandascore_service.fetch_past_matches(
            league: league,
            per_page: per_page
          )

          render json: {
            message: 'Past matches retrieved successfully',
            data: {
              matches: matches,
              source: 'pandascore',
              cached: true
            }
          }
        rescue ::Competitive::Services::PandascoreService::PandascoreError => e
          render json: {
            error: {
              code: 'PANDASCORE_ERROR',
              message: e.message
            }
          }, status: :service_unavailable
        end

        # POST /api/v1/competitive/pro-matches/refresh
        # Force refresh of PandaScore cache (owner only)
        def refresh
          authorize :pro_match, :refresh?

          @pandascore_service.clear_cache

          render json: {
            message: 'Cache cleared successfully',
            data: { cleared_at: Time.current }
          }
        rescue Pundit::NotAuthorizedError
          render json: {
            error: {
              code: 'FORBIDDEN',
              message: 'Only organization owners can refresh cache'
            }
          }, status: :forbidden
        end

        # POST /api/v1/competitive/pro-matches/import
        # Import a match from PandaScore to our database
        def import
          match_id = params[:match_id]
          raise ArgumentError, 'match_id is required' if match_id.blank?

          # Fetch match details from PandaScore
          match_data = @pandascore_service.fetch_match_details(match_id)

          # Import to our database (implement import logic)
          imported_match = import_match_to_database(match_data)

          render json: {
            message: 'Match imported successfully',
            data: {
              match: ::Competitive::Serializers::ProMatchSerializer.render_as_hash(imported_match)
            }
          }, status: :created
        rescue ::Competitive::Services::PandascoreService::NotFoundError
          render json: {
            error: {
              code: 'MATCH_NOT_FOUND',
              message: 'Match not found in PandaScore'
            }
          }, status: :not_found
        rescue ArgumentError => e
          render json: {
            error: {
              code: 'INVALID_PARAMS',
              message: e.message
            }
          }, status: :unprocessable_entity
        end

        private

        def set_pandascore_service
          @pandascore_service = ::Competitive::Services::PandascoreService.instance
        end

        def apply_filters(matches)
          matches = matches.by_tournament(params[:tournament]) if params[:tournament].present?
          matches = matches.by_region(params[:region]) if params[:region].present?
          matches = matches.by_patch(params[:patch]) if params[:patch].present?
          matches = matches.victories if params[:victories_only] == 'true'
          matches = matches.defeats if params[:defeats_only] == 'true'

          if params[:start_date].present? && params[:end_date].present?
            matches = matches.in_date_range(
              Date.parse(params[:start_date]),
              Date.parse(params[:end_date])
            )
          end

          matches
        end

        def pagination_meta(collection)
          {
            current_page: collection.current_page,
            total_pages: collection.total_pages,
            total_count: collection.total_count,
            per_page: collection.limit_value
          }
        end

        def import_match_to_database(match_data)
          # TODO: Implement match import logic
          # This would parse PandaScore match data and create a CompetitiveMatch record
          # For now, return a placeholder
          raise NotImplementedError, 'Match import not yet implemented'
        end
      end
    end
  end
end
