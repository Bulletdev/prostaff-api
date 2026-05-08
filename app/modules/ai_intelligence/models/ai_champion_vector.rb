# frozen_string_literal: true

# Stores normalized 5-dimensional performance vectors per champion.
# Dimensions: [win_rate, avg_kda, avg_damage_share, avg_gold_share, avg_cs]
# Global table (no organization_id, no RLS).
class AiChampionVector < ApplicationRecord
  validates :champion_name, presence: true, uniqueness: true

  def vector
    Numo::DFloat[*vector_data]
  end
end
