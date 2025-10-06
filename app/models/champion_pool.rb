class ChampionPool < ApplicationRecord
  # Associations
  belongs_to :player

  # Validations
  validates :champion, presence: true
  validates :player_id, uniqueness: { scope: :champion }
  validates :games_played, :games_won, numericality: { greater_than_or_equal_to: 0 }
  validates :mastery_level, inclusion: { in: 1..7 }
  validates :priority, inclusion: { in: 1..10 }

  # Scopes
  scope :comfort_picks, -> { where(is_comfort_pick: true) }
  scope :pocket_picks, -> { where(is_pocket_pick: true) }
  scope :learning, -> { where(is_learning: true) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :high_priority, -> { where(priority: 8..10) }
  scope :medium_priority, -> { where(priority: 4..7) }
  scope :low_priority, -> { where(priority: 1..3) }
  scope :most_played, -> { order(games_played: :desc) }
  scope :best_performance, -> { order(average_kda: :desc) }

  # Instance methods
  def win_rate
    return 0 if games_played.zero?

    (games_won.to_f / games_played * 100).round(1)
  end

  def win_rate_display
    "#{win_rate}%"
  end

  def games_lost
    games_played - games_won
  end

  def performance_tier
    return 'Learning' if is_learning?
    return 'Pocket Pick' if is_pocket_pick?
    return 'Comfort Pick' if is_comfort_pick?

    case win_rate
    when 0...40 then 'Needs Practice'
    when 40...60 then 'Decent'
    when 60...75 then 'Good'
    when 75...90 then 'Excellent'
    else 'Master'
    end
  end

  def mastery_display
    case mastery_level
    when 1..4 then "Mastery #{mastery_level}"
    when 5 then "Mastery 5"
    when 6 then "Mastery 6"
    when 7 then "Mastery 7"
    end
  end

  def priority_label
    case priority
    when 9..10 then 'Must Ban'
    when 7..8 then 'High Priority'
    when 4..6 then 'Medium Priority'
    when 2..3 then 'Low Priority'
    when 1 then 'Situational'
    end
  end

  def recently_played?
    last_played.present? && last_played >= 2.weeks.ago
  end

  def needs_practice?
    games_played < 5 || win_rate < 50 || !recently_played?
  end

  def champion_role
    # This could be enhanced with actual champion data
    # For now, return the player's main role
    player.role
  end

  def update_stats!(new_game_won:, new_kda: nil, new_cs_per_min: nil, new_damage_share: nil)
    self.games_played += 1
    self.games_won += 1 if new_game_won
    self.last_played = Time.current

    # Update averages if new stats provided
    if new_kda
      current_total_kda = (average_kda || 0) * (games_played - 1)
      self.average_kda = (current_total_kda + new_kda) / games_played
    end

    if new_cs_per_min
      current_total_cs = (average_cs_per_min || 0) * (games_played - 1)
      self.average_cs_per_min = (current_total_cs + new_cs_per_min) / games_played
    end

    if new_damage_share
      current_total_damage = (average_damage_share || 0) * (games_played - 1)
      self.average_damage_share = (current_total_damage + new_damage_share) / games_played
    end

    save!
  end

  def self.top_champions_for_role(role, limit: 10)
    joins(:player)
      .where(players: { role: role })
      .group(:champion)
      .average(:average_kda)
      .sort_by { |_, kda| -kda }
      .first(limit)
      .map(&:first)
  end
end