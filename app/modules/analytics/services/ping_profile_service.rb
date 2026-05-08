# frozen_string_literal: true

# Calculates a player's ping communication profile from recent match history.
# Uses ping data stored in player_match_stats.pings (jsonb) to derive
# behavioral metrics useful for coaching: map awareness, leadership, and communication style.
class PingProfileService
  AWARENESS_KEYS  = %w[enemy_missing danger enemy_vision].freeze
  LEADERSHIP_KEYS = %w[command on_my_way push hold].freeze
  DEFENSIVE_KEYS  = %w[get_back retreat danger].freeze
  ALL_PING_KEYS   = %w[
    all_in assist_me bait basic command danger
    enemy_missing enemy_vision get_back hold need_vision
    on_my_way push retreat vision_cleared
  ].freeze

  def initialize(player, matches_limit: 20)
    @player = player
    @matches_limit = matches_limit
  end

  def calculate
    stats = fetch_stats_with_pings
    return empty_profile if stats.empty?

    ping_totals = aggregate_ping_totals(stats)
    total = ping_totals.values.sum

    {
      player_id: @player.id,
      games_analyzed: stats.size,
      total_pings: total,
      avg_pings_per_game: total.zero? ? 0 : (total.to_f / stats.size).round(1),
      breakdown: ping_totals,
      scores: calculate_scores(ping_totals, total),
      profile_label: determine_profile_label(ping_totals, total)
    }
  end

  private

  def fetch_stats_with_pings
    PlayerMatchStat
      .where(player: @player)
      .where("pings != '{}'::jsonb")
      .order(created_at: :desc)
      .limit(@matches_limit)
  end

  def aggregate_ping_totals(stats)
    totals = ALL_PING_KEYS.each_with_object({}) { |k, h| h[k] = 0 }
    stats.each do |stat|
      next if stat.pings.blank?

      ALL_PING_KEYS.each { |key| totals[key] += stat.pings[key].to_i }
    end
    totals
  end

  def calculate_scores(ping_totals, total)
    return zeroed_scores if total.zero?

    {
      awareness: score_for_keys(ping_totals, AWARENESS_KEYS, total),
      leadership: score_for_keys(ping_totals, LEADERSHIP_KEYS, total),
      defensive: score_for_keys(ping_totals, DEFENSIVE_KEYS, total)
    }
  end

  def score_for_keys(ping_totals, keys, total)
    category_total = keys.sum { |k| ping_totals[k].to_i }
    (category_total.to_f / total * 100).round(1)
  end

  def determine_profile_label(ping_totals, total)
    return 'unknown' if total.zero?

    scores = calculate_scores(ping_totals, total)
    max_category = scores.max_by { |_, v| v }

    case max_category[0]
    when :awareness  then 'map_caller'
    when :leadership then 'shotcaller'
    when :defensive  then 'defensive_anchor'
    else 'balanced'
    end
  end

  def empty_profile
    {
      player_id: @player&.id,
      games_analyzed: 0,
      total_pings: 0,
      avg_pings_per_game: 0,
      breakdown: ALL_PING_KEYS.each_with_object({}) { |k, h| h[k] = 0 },
      scores: zeroed_scores,
      profile_label: 'unknown'
    }
  end

  def zeroed_scores
    { awareness: 0, leadership: 0, defensive: 0 }
  end
end
