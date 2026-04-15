# frozen_string_literal: true

# Fetches recent match history for a scouting target and aggregates
# per-champion and overall performance stats.
#
# Used by both SyncScoutingTargetJob (background) and the inline sync
# action in Scouting::PlayersController (synchronous response).
class PerformanceAggregator
  MATCH_COUNT = 20

  def initialize(riot_service:)
    @riot = riot_service
  end

  # Returns a hash ready to be stored in target.recent_performance.
  # Returns nil if the PUUID is missing or no match data is available.
  def call(puuid:, region:)
    return nil if puuid.blank?

    match_ids = @riot.get_match_history(puuid: puuid, region: region, count: MATCH_COUNT)
    return nil if match_ids.empty?

    stats = collect_stats(match_ids, puuid, region)
    return nil if stats.empty?

    build_summary(stats)
  rescue RiotApiService::RiotApiError => e
    Rails.logger.warn("[PerformanceAggregator] Skipping match fetch: #{e.message}")
    nil
  end

  private

  def collect_stats(match_ids, puuid, region)
    match_ids.filter_map do |match_id|
      details = @riot.get_match_details(match_id: match_id, region: region)
      details[:participants].find { |p| p[:puuid] == puuid }
    rescue RiotApiService::RiotApiError => e
      Rails.logger.warn("[PerformanceAggregator] Could not fetch #{match_id}: #{e.message}")
      nil
    end
  end

  def build_summary(stats)
    aggregate_overall(stats).merge(
      champion_pool_stats: aggregate_per_champion(stats),
      matches_analyzed: stats.size
    )
  end

  def aggregate_overall(stats)
    totals = sum_stats(stats)
    wins   = stats.count { |p| p[:win] }
    total  = stats.size

    overall_hash(totals, wins, total)
  end

  def overall_hash(totals, wins, total) # rubocop:disable Metrics/AbcSize
    {
      games_played: total,
      win_rate: (wins.to_f / total * 100).round(1),
      avg_kda: kda_ratio(totals[:kills], totals[:deaths], totals[:assists], total).round(2),
      avg_kills: (totals[:kills].to_f / total).round(1),
      avg_deaths: (totals[:deaths].to_f / total).round(1),
      avg_assists: (totals[:assists].to_f / total).round(1),
      avg_vision_score: (totals[:vision].to_f / total).round(1),
      avg_cs_per_min: (totals[:cs].to_f / total).round(1)
    }
  end

  def aggregate_per_champion(stats)
    stats.group_by { |p| p[:champion_name] }
         .map { |champion, games| champion_row(champion, games) }
         .sort_by { |c| -c[:games] }
  end

  def champion_row(champion, games) # rubocop:disable Metrics/AbcSize
    totals = sum_stats(games)
    wins   = games.count { |p| p[:win] }
    total  = games.size

    {
      champion: champion,
      games: total,
      wins: wins,
      winrate: (wins.to_f / total * 100).round(1),
      kda_ratio: kda_ratio(totals[:kills], totals[:deaths], totals[:assists], total).round(2),
      avg_kills: (totals[:kills].to_f / total).round(1),
      avg_deaths: (totals[:deaths].to_f / total).round(1),
      avg_assists: (totals[:assists].to_f / total).round(1),
      avg_cs_per_min: (totals[:cs].to_f / total).round(1)
    }
  end

  def sum_stats(stats)
    {
      kills: stats.sum { |p| p[:kills].to_i },
      deaths: stats.sum { |p| p[:deaths].to_i },
      assists: stats.sum { |p| p[:assists].to_i },
      vision: stats.sum { |p| p[:vision_score].to_i },
      cs: stats.sum { |p| p[:minions_killed].to_i + p[:neutral_minions_killed].to_i }
    }
  end

  def kda_ratio(kills, deaths, assists, total)
    avg_deaths = deaths.to_f / total
    return (kills + assists).to_f / total if avg_deaths.zero?

    (kills + assists).to_f / deaths
  end
end
