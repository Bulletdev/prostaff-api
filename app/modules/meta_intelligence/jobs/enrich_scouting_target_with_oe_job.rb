# frozen_string_literal: true

module MetaIntelligence
  # Enriches a ScoutingTarget with its latest Oracle's Elixir split stats.
  class EnrichScoutingTargetWithOeJob < ApplicationJob
    queue_as :meta_intelligence

    include OeStatSerializable

    def perform(target_id)
      target = ScoutingTarget.find_by(id: target_id)
      return unless target&.professional_name.present?

      oe = OePlayerLookupService.latest_stats(target.professional_name)
      return unless oe

      target.update!(
        recent_performance: (target.recent_performance || {}).merge(
          'oe_last_split' => serialize_oe_player_stat(oe)
        )
      )
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[EnrichScoutingTargetWithOeJob] #{e.message}")
    end
  end
end
