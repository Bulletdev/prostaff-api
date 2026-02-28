# frozen_string_literal: true

module MetaIntelligence
  module Controllers
    # Returns optimal build information for a specific champion.
    #
    # Queries saved_builds for the best-performing build for a given champion,
    # with optional filtering by role and patch. Only builds with a sufficient
    # sample size (MINIMUM_SAMPLE_SIZE) are considered for recommendations.
    #
    # @example Get optimal Jinx ADC build for current patch
    #   GET /api/v1/meta/champions/Jinx?role=adc&patch=14.24
    #
    # @example Get all builds for a champion across roles
    #   GET /api/v1/meta/champions/Ahri
    class ChampionMetaController < Api::V1::BaseController
      # GET /api/v1/meta/champions/:champion
      #
      # @param [String] champion champion name (e.g. 'Jinx', 'LeBlanc')
      # @param [String] role     filter by role (optional): top/jungle/mid/adc/support
      # @param [String] patch    filter by patch version (optional)
      # @return [JSON] { data: { champion:, optimal_build:, all_builds: [...] } }
      def show
        champion = params[:champion]
        builds   = find_builds(champion)

        render_success(
          {
            champion: champion,
            optimal_build: serialize_build(builds.first),
            all_builds: SavedBuildSerializer.render_as_hash(builds.first(5))
          },
          message: "Champion meta for #{champion}"
        )
      end

      private

      def find_builds(champion)
        scope = current_organization.saved_builds
                                    .by_champion(champion)
                                    .with_sufficient_sample
                                    .ranked_by_win_rate

        scope = scope.by_role(params[:role])    if params[:role].present?
        scope = scope.by_patch(params[:patch])  if params[:patch].present?

        scope
      end

      def serialize_build(build)
        return nil unless build

        SavedBuildSerializer.render_as_hash(build)
      end
    end
  end
end
