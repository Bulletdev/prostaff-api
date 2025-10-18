class PlayerMatchStat < ApplicationRecord
  belongs_to :match
  belongs_to :player

  validates :champion, presence: true
  validates :kills, :deaths, :assists, :cs, numericality: { greater_than_or_equal_to: 0 }
  validates :player_id, uniqueness: { scope: :match_id }

  before_save :calculate_derived_stats
  after_create :update_champion_pool
  after_update :log_audit_trail, if: :saved_changes?

  scope :by_champion, ->(champion) { where(champion: champion) }
  scope :by_role, ->(role) { where(role: role) }
  scope :recent, ->(days = 30) { joins(:match).where(matches: { game_start: days.days.ago..Time.current }) }
  scope :victories, -> { joins(:match).where(matches: { victory: true }) }
  scope :defeats, -> { joins(:match).where(matches: { victory: false }) }

  def kda_ratio
    return 0 if deaths.zero?

    (kills + assists).to_f / deaths
  end

  def kda_display
    "#{kills}/#{deaths}/#{assists}"
  end

  def kill_participation_percentage
    return 0 if kill_participation.blank?

    (kill_participation * 100).round(1)
  end

  def damage_share_percentage
    return 0 if damage_share.blank?

    (damage_share * 100).round(1)
  end

  def gold_share_percentage
    return 0 if gold_share.blank?

    (gold_share * 100).round(1)
  end

  def multikill_count
    double_kills + triple_kills + quadra_kills + penta_kills
  end


  def grade_performance
    total_score = kda_score + cs_score + damage_score + vision_performance_score
    average_score = total_score / 4.0

    score_to_grade(average_score)
  end

  def item_names
    # This would be populated by Riot API data
    # For now, return item IDs as placeholder
    items.map { |item_id| "Item #{item_id}" }
  end

  def rune_names
    # This would be populated by Riot API data
    # For now, return rune IDs as placeholder
    runes.map { |rune_id| "Rune #{rune_id}" }
  end

  private

  def kda_score
    case kda_ratio
    when 0...1 then 1
    when 1...2 then 2
    when 2...3 then 3
    when 3...4 then 4
    else 5
    end
  end

  def cs_score
    cs_value = cs_per_min || 0
    case cs_value
    when 0...4 then 1
    when 4...6 then 2
    when 6...8 then 3
    when 8...10 then 4
    else 5
    end
  end

  def damage_score
    case damage_share_percentage
    when 0...15 then 1
    when 15...20 then 2
    when 20...25 then 3
    when 25...30 then 4
    else 5
    end
  end

  def vision_performance_score
    vision_per_min = match&.game_duration.present? ? vision_score.to_f / (match.game_duration / 60.0) : 0
    case vision_per_min
    when 0...1 then 1
    when 1...1.5 then 2
    when 1.5...2 then 3
    when 2...2.5 then 4
    else 5
    end
  end

  def score_to_grade(average)
    case average
    when 0...1.5 then 'D'
    when 1.5...2.5 then 'C'
    when 2.5...3.5 then 'B'
    when 3.5...4.5 then 'A'
    else 'S'
    end
  end

  def calculate_derived_stats
    if match&.game_duration.present? && match.game_duration > 0
      minutes = match.game_duration / 60.0
      self.cs_per_min = cs.to_f / minutes if cs.present?
      self.gold_per_min = gold_earned.to_f / minutes if gold_earned.present?
    end

    # Calculate performance score (0-100)
    self.performance_score = calculate_performance_score
  end

  def calculate_performance_score
    return 0 unless match

    score = 0

    # KDA component (40 points max)
    kda = kda_ratio
    score += [kda * 10, 40].min

    # CS component (20 points max)
    cs_score = (cs_per_min || 0) * 2.5
    score += [cs_score, 20].min

    # Damage component (20 points max)
    damage_score = (damage_share || 0) * 100 * 0.8
    score += [damage_score, 20].min

    # Vision component (10 points max)
    vision_score_normalized = vision_score.to_f / 100
    score += [vision_score_normalized * 10, 10].min

    # Victory bonus (10 points max)
    score += 10 if match.victory?

    [score, 100].min.round(2)
  end

  def update_champion_pool
    pool = player.champion_pools.find_or_initialize_by(champion: champion)

    pool.games_played += 1
    pool.games_won += 1 if match.victory?

    pool.average_kda = calculate_average_for_champion(:kda_ratio)
    pool.average_cs_per_min = calculate_average_for_champion(:cs_per_min)
    pool.average_damage_share = calculate_average_for_champion(:damage_share)

    pool.last_played = match.game_start || Time.current
    pool.save!
  end

  def calculate_average_for_champion(stat_method)
    stats = player.player_match_stats.joins(:match).where(champion: champion)
    values = stats.map { |stat| stat.send(stat_method) }.compact
    return 0 if values.empty?

    values.sum / values.size.to_f
  end

  def log_audit_trail
    AuditLog.create!(
      organization: player.organization,
      action: 'update',
      entity_type: 'PlayerMatchStat',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end
end