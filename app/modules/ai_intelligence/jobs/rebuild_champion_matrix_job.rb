# frozen_string_literal: true

module AiIntelligence
  # Rebuilds champion matrices and vectors from all CompetitiveMatch records.
  # Runs in low_priority queue — triggered after each scraper sync or nightly via sidekiq-scheduler.
  # Uses CompetitiveMatch.unscoped intentionally (global dataset, no org context needed).
  class RebuildChampionMatrixJob < ApplicationJob
    queue_as :low_priority

    def perform(scope: :all, league: nil)
      lock_key = 'sidekiq:rebuild_champion_matrix:lock'
      acquired = Sidekiq.redis { |r| r.call('SET', lock_key, '1', 'NX', 'EX', 3600) }

      unless acquired
        Rails.logger.info('[AI] RebuildChampionMatrixJob skipped — already running')
        return
      end

      # 31k+ records with per-row upserts exceed the default 10s statement_timeout.
      # Scope this to the current session only — the connection returns to the pool
      # with its normal timeout restored after the job finishes.
      ActiveRecord::Base.connection.execute('SET statement_timeout = 0')
      rebuild_matrices(scope:, league:)
    ensure
      Sidekiq.redis { |r| r.call('DEL', lock_key) } if acquired
    end

    private

    def rebuild_matrices(scope:, league:)
      Rails.logger.info("[AI] Starting champion matrix rebuild scope=#{scope} league=#{league}")
      ChampionMatrixBuilder.call(scope: scope.to_sym, league:)
      ChampionVectorBuilder.rebuild_all!
      Rails.logger.info("[AI] Champion matrices rebuilt at #{Time.current}")
    end
  end
end
