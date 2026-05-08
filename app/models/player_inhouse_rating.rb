# frozen_string_literal: true

# Stores per-player, per-role TrueSkill ratings for the inhouse ladder.
#
# One record per (player, role) pair. Created on first game and updated
# after every record_game call via TrueSkillService.
#
# @example Find or initialise a rating
#   rating = PlayerInhouseRating.for(player, role)
#   rating.mmr  # => 0 (fresh player)
#
class PlayerInhouseRating < ApplicationRecord
  MU_INITIAL    = 25.0
  SIGMA_INITIAL = 25.0 / 3.0 # ≈ 8.333
  ROLES         = %w[top jungle mid adc support fill].freeze

  belongs_to :player
  belongs_to :organization

  validates :role, inclusion: { in: ROLES }
  validates :player_id, uniqueness: { scope: :role }
  validates :mu, :sigma, :games_played, :wins, :losses, presence: true

  # Conservative skill estimate used for ladder ranking.
  # Returns an integer in roughly 0–3000 range.
  def mmr
    [((mu - (3.0 * sigma)) * 100).round, 0].max
  end

  def win_rate
    return 0.0 if games_played.zero?

    (wins.to_f / games_played * 100).round(1)
  end

  # Find an existing rating or build a fresh one (unsaved).
  def self.for(player, role, organization)
    find_or_initialize_by(player: player, role: role) do |r|
      r.organization = organization
      r.mu           = MU_INITIAL
      r.sigma        = SIGMA_INITIAL
    end
  end
end
