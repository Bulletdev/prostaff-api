# frozen_string_literal: true

# Concern for comparing League of Legends ranks
#
# Provides utilities for determining if a new rank is higher than a current rank.
# Used in sync jobs to update peak rank information.

module RankComparison
  extend ActiveSupport::Concern

  TIER_HIERARCHY = %w[IRON BRONZE SILVER GOLD PLATINUM EMERALD DIAMOND MASTER GRANDMASTER CHALLENGER].freeze

  RANK_HIERARCHY = %w[IV III II I].freeze


  def should_update_peak?(entity, new_tier, new_rank)
    return true if entity.peak_tier.blank?

    current_tier_index = tier_index(entity.peak_tier)
    new_tier_index = tier_index(new_tier)

    return true if new_tier_higher?(new_tier_index, current_tier_index)
    return false if new_tier_lower?(new_tier_index, current_tier_index)

    new_rank_higher?(entity.peak_rank, new_rank)
  end

  private

  def tier_index(tier)
    TIER_HIERARCHY.index(tier&.upcase) || 0
  end

  def rank_index(rank)
    RANK_HIERARCHY.index(rank&.upcase) || 0
  end

  def new_tier_higher?(new_index, current_index)
    new_index > current_index
  end

  def new_tier_lower?(new_index, current_index)
    new_index < current_index
  end

  def new_rank_higher?(current_rank, new_rank)
    rank_index(new_rank) > rank_index(current_rank)
  end
end
