# frozen_string_literal: true

module MetaIntelligence
  module Controllers
    # CRUD for saved builds with analytics data.
    #
    # Coaches can create manual builds; the system generates aggregated
    # builds automatically via UpdateMetaStatsJob.
    #
    # All operations are organization-scoped (multi-tenant safe).
    #
    # @example List ADC builds for current patch
    #   GET /api/v1/meta/builds?role=adc&patch=14.24
    #
    # @example Create a manual build
    #   POST /api/v1/meta/builds
    #   Body: { build: { champion: "Jinx", role: "adc", items: [3153, 3006, ...] } }
    #
    # @example Trigger aggregation
    #   POST /api/v1/meta/builds/aggregate
    class BuildsController < Api::V1::BaseController
      before_action :set_build, only: %i[show update destroy]
      before_action -> { require_role!('owner', 'admin', 'coach') }, only: %i[aggregate]

      # GET /api/v1/meta/builds
      #
      # @param [String] champion  filter by champion name (optional)
      # @param [String] role      filter by role: top/jungle/mid/adc/support (optional)
      # @param [String] patch     filter by patch version (optional)
      # @param [String] source    filter by data_source: 'manual' or 'aggregated' (optional)
      # @return [JSON] { data: { builds: [...] } }
      def index
        builds = apply_filters(current_organization.saved_builds.ranked_by_win_rate)
        render_success(
          { builds: SavedBuildSerializer.render_as_hash(builds) },
          message: 'Builds retrieved'
        )
      end

      # GET /api/v1/meta/builds/:id
      # @return [JSON] { data: { build: {...} } }
      def show
        render_success(
          { build: SavedBuildSerializer.render_as_hash(@build) },
          message: 'Build retrieved'
        )
      end

      # POST /api/v1/meta/builds
      #
      # Creates a manual build entry. data_source is forced to 'manual'.
      # @return [JSON] { data: { build: {...} } }
      def create
        build = current_organization.saved_builds.new(build_create_params)
        build.created_by  = current_user
        build.data_source = 'manual'

        if build.save
          render_created({ build: SavedBuildSerializer.render_as_hash(build) })
        else
          render_error(
            message: 'Failed to create build',
            details: build.errors.full_messages,
            status: :unprocessable_entity
          )
        end
      end

      # PATCH /api/v1/meta/builds/:id
      # @return [JSON] { data: { build: {...} } }
      def update
        if @build.update(build_update_params)
          render_success(
            { build: SavedBuildSerializer.render_as_hash(@build) },
            message: 'Build updated'
          )
        else
          render_error(
            message: 'Failed to update build',
            details: @build.errors.full_messages,
            status: :unprocessable_entity
          )
        end
      end

      # DELETE /api/v1/meta/builds/:id
      # @return [JSON] 200 with deletion confirmation
      def destroy
        @build.destroy!
        render_deleted
      end

      # POST /api/v1/meta/builds/aggregate
      #
      # Enqueues UpdateMetaStatsJob for the current organization.
      # Accessible by owners, admins, and coaches.
      #
      # @param [String] scope   'org' (default) or 'org+scouting'
      # @param [String] patch   specific patch to aggregate (optional)
      # @return [JSON] { message: 'Aggregation enqueued' }
      def aggregate
        Jobs::UpdateMetaStatsJob.perform_later(
          current_organization.id,
          scope: params[:scope] || 'org',
          patch: params[:patch]
        )

        render_success({}, message: 'Aggregation job enqueued')
      end

      private

      def set_build
        @build = current_organization.saved_builds.find(params[:id])
      end

      def apply_filters(scope)
        scope = scope.by_champion(params[:champion]) if params[:champion].present?
        scope = scope.by_role(params[:role])         if params[:role].present?
        scope = scope.by_patch(params[:patch])       if params[:patch].present?
        scope = scope.where(data_source: params[:source]) if params[:source].present?
        scope
      end

      def build_create_params
        # nosemgrep: ruby.lang.security.model-attr-accessible.model-attr-accessible
        # :role is the LoL champion role (adc/jungle/mid/etc.), not a user authorization role.
        # SavedBuild has no admin/banned/account_id fields — mass assignment risk does not apply.
        params.require(:build).permit(
          :champion, :role, :patch_version, :title, :notes, :is_public,
          :primary_rune_tree, :secondary_rune_tree,
          :summoner_spell_1, :summoner_spell_2, :trinket,
          items: [], item_build_order: [], runes: []
        )
      end

      def build_update_params
        params.require(:build).permit(
          :title, :notes, :is_public, :patch_version,
          :primary_rune_tree, :secondary_rune_tree,
          :summoner_spell_1, :summoner_spell_2, :trinket,
          items: [], item_build_order: [], runes: []
        )
      end
    end
  end
end
