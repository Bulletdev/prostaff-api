# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/search?q=<term>[&types=players,organizations][&per_page=20]
    #
    # Multi-index full-text search powered by Meilisearch Cloud.
    # Returns grouped results per index.
    #
    # Query params:
    #   q        [String]  required — search term
    #   types    [String]  optional — comma-separated index names to search
    #                      (players, organizations, scouting_targets,
    #                       opponent_teams, support_faqs)
    #   per_page [Integer] optional — hits per index, default 20, max 100
    class SearchController < Api::V1::BaseController
      ALLOWED_TYPES = SearchService::INDEXES.keys.freeze
      MAX_PER_PAGE  = 100

      def index
        query = params[:q].to_s.strip
        return render_error('Missing required parameter: q', :bad_request) if query.blank?

        types    = parse_types
        per_page = [[params[:per_page].to_i, 1].max, MAX_PER_PAGE].min
        per_page = 20 if params[:per_page].blank?

        results = SearchService.global(query: query, types: types, per_page: per_page)

        render_success({
                         query: query,
                         types: types || ALLOWED_TYPES,
                         results: results
                       })
      end

      private

      def parse_types
        return nil if params[:types].blank?

        requested = params[:types].split(',').map(&:strip)
        valid     = requested & ALLOWED_TYPES
        valid.presence
      end
    end
  end
end
