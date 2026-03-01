# frozen_string_literal: true

module MetaIntelligence
  # Sidekiq background job to aggregate match history into meta intelligence stats.
  #
  # Triggers BuildAggregatorService and then syncs results to Meilisearch.
  #
  # This job is enqueued:
  #   - After SyncMatchJob completes (via after_perform hook)
  #   - Manually via the POST /api/v1/meta/builds/aggregate endpoint
  #
  # It is idempotent: re-running produces the same final state (upsert semantics).
  #
  # @example Enqueue for an organization
  #   MetaIntelligence::UpdateMetaStatsJob.perform_later(org.id)
  #
  # @example Enqueue for a specific patch
  #   MetaIntelligence::UpdateMetaStatsJob.perform_later(org.id, patch: '14.24')
  class UpdateMetaStatsJob < ApplicationJob
    queue_as :meta_intelligence

    retry_on StandardError, wait: 5.minutes, attempts: 3

    # @param organization_id [String] UUID of the organization
    # @param scope [String] 'org' or 'org+scouting' (default: 'org')
    # @param patch [String, nil] specific patch to aggregate (default: all patches)
    def perform(organization_id, scope: 'org', patch: nil)
      organization = Organization.find(organization_id)

      log_start(organization_id, scope, patch)

      result = run_aggregation(organization, scope, patch)
      sync_to_search(organization)

      log_complete(organization_id, result)
    end

    private

    def run_aggregation(organization, scope, patch)
      BuildAggregatorService.new(
        organization: organization,
        scope: scope,
        patch: patch
      ).call
    end

    def sync_to_search(organization)
      indexer = MetaIndexerService.new(organization: organization)
      indexer.sync_builds
      indexer.sync_items
    end

    def log_start(organization_id, scope, patch)
      Rails.logger.info(
        '[MetaIntelligence] UpdateMetaStatsJob starting — ' \
        "org=#{organization_id} scope=#{scope} patch=#{patch || 'all'}"
      )
    end

    def log_complete(organization_id, result)
      Rails.logger.info(
        '[MetaIntelligence] UpdateMetaStatsJob complete — ' \
        "org=#{organization_id} result=#{result.inspect}"
      )
    end
  end
end
