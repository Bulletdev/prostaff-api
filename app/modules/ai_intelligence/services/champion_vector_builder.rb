# frozen_string_literal: true

# Builds normalized 5-dimensional performance vectors per champion from CompetitiveMatch JSONB data.
# Uses CompetitiveMatch.unscoped to aggregate across all organizations (global dataset).
#
# Dimensions: [win_rate, avg_kda, avg_damage_share, avg_gold_share, avg_cs]
class ChampionVectorBuilder
  DIMENSIONS = %i[win_rate avg_kda avg_damage_share avg_gold_share avg_cs].freeze

  def initialize(champion_name:, league: nil)
    @champion_name = champion_name
    @league        = league
  end

  def self.call(champion_name:, league: nil)
    new(champion_name:, league:).build
  end

  def self.rebuild_all!
    all_matches = CompetitiveMatch.unscoped.to_a
    collect_champion_names(all_matches).each { |name| persist_vector(name, all_matches) }
  end

  def build
    stats = aggregate_stats
    return nil if stats[:games].zero?

    vector = Numo::DFloat[
      stats[:win_rate],
      stats[:avg_kda],
      stats[:avg_damage_share],
      stats[:avg_gold_share],
      normalize(stats[:avg_cs], 0, 400)
    ]
    normalize_vector(vector)
  end

  def appearances_from_preloaded(matches)
    filtered = @league ? matches.select { |m| m.tournament_name == @league } : matches
    filtered.flat_map { |match| extract_from_match(match) }
  end

  def build_from_appearances(appearances)
    arrays = extract_stat_arrays(appearances)
    stats = build_stat_hash(appearances.size, arrays)
    vector = Numo::DFloat[
      stats[:win_rate], stats[:avg_kda], stats[:avg_damage_share],
      stats[:avg_gold_share], normalize(stats[:avg_cs], 0, 400)
    ]
    normalize_vector(vector)
  end

  private

  def self.collect_champion_names(matches)
    matches.flat_map { |m|
      ((m.our_picks || []) + (m.opponent_picks || [])).map { |p| p['champion'] }
    }.compact.uniq
  end
  private_class_method :collect_champion_names

  def self.persist_vector(champion_name, all_matches)
    builder = new(champion_name: champion_name)
    appearances = builder.appearances_from_preloaded(all_matches)
    return if appearances.empty?

    vector = builder.build_from_appearances(appearances)

    AiChampionVector.find_or_initialize_by(champion_name: champion_name).tap do |v|
      v.vector_data = vector.to_a
      v.games_count = appearances.size
      v.updated_at  = Time.current
      v.save!
    end
  end
  private_class_method :persist_vector

  def aggregate_stats
    appearances = all_appearances
    return { games: 0 } if appearances.empty?

    arrays = extract_stat_arrays(appearances)
    build_stat_hash(appearances.size, arrays)
  end

  def extract_stat_arrays(appearances)
    {
      wins: appearances.count { |p| p['win'] },
      kdas: appearances.map { |p| kda(p) },
      damages: appearances.map { |p| p['damage_share'] || 0 },
      golds: appearances.map { |p| p['gold_share'] || 0 },
      css: appearances.map { |p| (p['cs'] || 0).to_f }
    }
  end

  def build_stat_hash(count, arrays)
    {
      games: count,
      win_rate: arrays[:wins].to_f / count,
      avg_kda: average(arrays[:kdas]),
      avg_damage_share: average(arrays[:damages]),
      avg_gold_share: average(arrays[:golds]),
      avg_cs: average(arrays[:css])
    }
  end

  def all_appearances
    scope = CompetitiveMatch.unscoped
    scope = scope.where(tournament_name: @league) if @league

    scope.flat_map { |match| extract_from_match(match) }
  end

  def extract_from_match(match)
    [match.our_picks, match.opponent_picks].flat_map do |picks|
      next [] if picks.blank?

      enrich_picks(picks)
    end
  end

  def enrich_picks(picks)
    team_damage = picks.sum { |p| (p['damage'] || 0).to_i }
    team_gold   = picks.sum { |p| (p['gold']   || 0).to_i }

    picks.filter_map do |pick|
      next unless pick['champion'].to_s.downcase == @champion_name.downcase

      pick.merge(
        'damage_share' => share_value(pick['damage'], team_damage),
        'gold_share' => share_value(pick['gold'], team_gold)
      )
    end
  end

  def share_value(player_stat, team_total)
    team_total.positive? ? player_stat.to_f / team_total : 0
  end

  def kda(pick)
    deaths = pick['deaths'].to_i
    return (pick['kills'].to_i + pick['assists'].to_i).to_f if deaths.zero?

    (pick['kills'].to_i + pick['assists'].to_i).to_f / deaths
  end

  def average(arr)
    arr.empty? ? 0.0 : arr.sum / arr.size.to_f
  end

  def normalize(value, min, max)
    range = max - min
    return 0.0 if range.zero?

    (value - min).clamp(0, range) / range.to_f
  end

  def normalize_vector(vec)
    norm = Math.sqrt((vec**2).sum)
    norm.zero? ? vec : vec / norm
  end
end
