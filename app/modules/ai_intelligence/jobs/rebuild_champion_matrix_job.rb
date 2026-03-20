# frozen_string_literal: true

module AiIntelligence
  # Rebuilds champion matrices and vectors from all CompetitiveMatch records.
  # Runs in low_priority queue — triggered after each scraper sync or nightly via sidekiq-scheduler.
  # Uses CompetitiveMatch.unscoped intentionally (global dataset, no org context needed).
  class RebuildChampionMatrixJob < ApplicationJob
    queue_as :low_priority

    def perform(scope: :all, league: nil)
      Rails.logger.info("[AI] Starting champion matrix rebuild scope=#{scope} league=#{league}")

      ChampionMatrixBuilder.call(scope: scope.to_sym, league:)
      ChampionVectorBuilder.rebuild_all!

      Rails.logger.info("[AI] Champion matrices rebuilt at #{Time.current}")
    end
  end
end
