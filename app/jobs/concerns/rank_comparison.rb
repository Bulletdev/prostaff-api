# frozen_string_literal: true

# Concern for comparing League of Legends ranks
#
# Provides utilities for determining if a new rank is higher than a current rank.
# Used in sync jobs to update peak rank information.
#
# Can be used as module methods or included in classes:
#   RankComparison.should_update_peak?(entity, new_tier, new_rank)
#   # or
#   include RankComparison
#   should_update_peak?(entity, new_tier, new_rank)
module RankComparison
  extend ActiveSupport::Concern

  TIER_HIERARCHY = %w[IRON BRONZE SILVER GOLD PLATINUM EMERALD DIAMOND MASTER GRANDMASTER CHALLENGER].freeze

  RANK_HIERARCHY = %w[IV III II I].freeze

  # Determines if peak rank should be updated
  #
  # @param entity [Object] Entity with peak_tier and peak_rank attributes
  # @param new_tier [String] New tier to compare
  # @param new_rank [String] New rank to compare
  # @return [Boolean] True if peak should be updated
  def should_update_peak?(entity, new_tier, new_rank)
    return true if entity.peak_tier.blank?

    current_tier_index = tier_index(entity.peak_tier)
    new_tier_index = tier_index(new_tier)

    return true if new_tier_higher?(new_tier_index, current_tier_index)
    return false if new_tier_lower?(new_tier_index, current_tier_index)

    new_rank_higher?(entity.peak_rank, new_rank)
  end
  module_function :should_update_peak?

  # Returns the index of a tier in the hierarchy
  #
  # @param tier [String] Tier name
  # @return [Integer] Index in hierarchy (0 for lowest)
  def tier_index(tier)
    TIER_HIERARCHY.index(tier&.upcase) || 0
  end
  module_function :tier_index

  # Returns the index of a rank within a tier
  #
  # @param rank [String] Rank (I, II, III, IV)
  # @return [Integer] Index in hierarchy (0 for lowest)
  def rank_index(rank)
    RANK_HIERARCHY.index(rank&.upcase) || 0
  end
  module_function :rank_index

  # Checks if new tier is higher than current
  #
  # @param new_index [Integer] New tier index
  # @param current_index [Integer] Current tier index
  # @return [Boolean] True if new tier is higher
  def new_tier_higher?(new_index, current_index)
    new_index > current_index
  end
  module_function :new_tier_higher?

  # Checks if new tier is lower than current
  #
  # @param new_index [Integer] New tier index
  # @param current_index [Integer] Current tier index
  # @return [Boolean] True if new tier is lower
  def new_tier_lower?(new_index, current_index)
    new_index < current_index
  end
  module_function :new_tier_lower?

  # Checks if new rank is higher than current within the same tier
  #
  # @param current_rank [String] Current rank
  # @param new_rank [String] New rank
  # @return [Boolean] True if new rank is higher
  def new_rank_higher?(current_rank, new_rank)
    rank_index(new_rank) > rank_index(current_rank)
  end
  module_function :new_rank_higher?
end
