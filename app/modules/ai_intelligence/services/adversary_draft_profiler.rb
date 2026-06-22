# frozen_string_literal: true

# Builds an adversary team's draft profile by merging two data sources:
#   1. Elasticsearch (ProStaff Scraper) — professional match history 2013–present
#   2. Local competitive_matches — games tracked by this organization
#
# The `ban_data_available` flag tells the caller whether bans from ES are
# present. It will be false until the Scraper backfill of blue_bans/red_bans
# completes (PRD section 5.2.2). The frontend should degrade gracefully.
#
# Cache TTL is handled by ProStaffScraperService (2min for adversary calls).
#
# @example
#   profiler = AdversaryDraftProfiler.new(
#     team: 'LOUD', league: 'CBLOL', last_n: 20, organization: org
#   )
#   result = profiler.call
#   result[:priority_picks]      # => { "mid" => ["Corki", "Azir"], ... }
#   result[:ban_data_available]  # => false (until backfill finishes)
class AdversaryDraftProfiler
  def initialize(team:, organization:, league: nil, last_n: 20)
    @team         = team
    @organization = organization
    @league       = league
    @last_n       = last_n
  end

  def call
    es_data    = fetch_es_profile
    local_data = fetch_local_profile

    merge_profiles(es_data, local_data)
  rescue ProStaffScraperService::NotFoundError
    fallback_to_local(fetch_local_profile)
  rescue ProStaffScraperService::UnavailableError => e
    Rails.logger.warn("[AdversaryDraftProfiler] scraper unavailable: #{e.message}")
    fallback_to_local(fetch_local_profile)
  end

  private

  def scraper
    @scraper ||= ProStaffScraperService.new
  end

  def fetch_es_profile
    scraper.fetch_adversary_profile(team: @team, league: @league, last_n: @last_n)
  rescue ProStaffScraperService::ScraperError => e
    Rails.logger.warn("[AdversaryDraftProfiler] ES error: #{e.message}")
    nil
  end

  def fetch_local_profile
    matches = @organization.competitive_matches
                           .where(opponent_team_name: @team)
                           .order(match_date: :desc)
                           .limit(@last_n)

    return nil if matches.empty?

    {
      games: matches.count,
      opponent_bans: extract_local_bans(matches),
      opponent_picks: extract_local_picks(matches)
    }
  end

  def extract_local_bans(matches)
    matches.flat_map { |m| m.opponent_bans.map { |b| b['champion'] }.compact }
           .tally
           .sort_by { |_, count| -count }
           .first(10)
           .map { |champ, count| { champion: champ, count: count } }
  end

  def extract_local_picks(matches)
    # opponent_picks is JSONB: [{ "champion" => "Ahri", "role" => "mid", ... }, ...]
    all_picks = matches.flat_map { |m| m.opponent_picks.presence || [] }
    group_picks_by_role(all_picks)
  rescue StandardError
    {}
  end

  def group_picks_by_role(picks)
    picks.group_by { |p| p['role'] || p[:role] }
         .transform_values { |group| top_champions_from(group) }
  end

  def top_champions_from(picks)
    picks.map { |p| p['champion'] || p[:champion] }
         .compact
         .tally
         .sort_by { |_, count| -count }
         .first(5)
         .map(&:first)
  end

  def merge_profiles(es_data, local_data)
    ctx = build_context(es_data, local_data)
    {
      team: @team,
      league: @league,
      games_analyzed: ctx[:games_es] + ctx[:games_local],
      data_sources: build_source_list(ctx[:has_es], local_data),
      ban_data_available: ctx[:has_ban],
      most_banned_against: extract_most_banned(es_data, local_data, ctx[:has_ban]),
      priority_picks: extract_priority_picks(es_data),
      blue_side_tendencies: extract_blue_side(es_data),
      red_side_tendencies: extract_red_side(es_data),
      local_games: ctx[:games_local]
    }
  end

  def build_context(es_data, local_data)
    has_es = es_data.present?
    {
      has_es: has_es,
      has_ban: has_es && (es_data['ban_data_available'] || es_data[:ban_data_available]),
      games_es: has_es ? (es_data['games'] || es_data[:games] || 0) : 0,
      games_local: local_data ? (local_data[:games] || 0) : 0
    }
  end

  def fallback_to_local(local_data)
    return empty_profile if local_data.nil?

    {
      team: @team,
      league: @league,
      games_analyzed: local_data[:games],
      data_sources: ['local_matches'],
      ban_data_available: false,
      most_banned_against: local_data[:opponent_bans].map { |b| b[:champion] }.first(5),
      priority_picks: local_data[:opponent_picks] || {},
      blue_side_tendencies: {},
      red_side_tendencies: {},
      local_games: local_data[:games]
    }
  end

  def empty_profile
    {
      team: @team, league: @league, games_analyzed: 0,
      data_sources: [], ban_data_available: false,
      most_banned_against: [], priority_picks: {},
      blue_side_tendencies: {}, red_side_tendencies: {}, local_games: 0
    }
  end

  def build_source_list(has_es, local_data)
    sources = []
    sources << 'elasticsearch' if has_es
    sources << 'local_matches' if local_data.present?
    sources
  end

  def extract_most_banned(es_data, local_data, has_ban)
    return [] unless has_ban || local_data

    es_banned = if has_ban && es_data
                  es_data['most_banned_against'] || es_data[:most_banned_against] || []
                else
                  []
                end

    local_banned = local_data ? local_data[:opponent_bans].map { |b| b[:champion] } : []

    (es_banned + local_banned).uniq.first(5)
  end

  def extract_priority_picks(es_data)
    return {} unless es_data

    es_data['priority_picks'] || es_data[:priority_picks] || {}
  end

  def extract_blue_side(es_data)
    return {} unless es_data

    es_data['blue_side_tendencies'] || es_data[:blue_side_tendencies] || {}
  end

  def extract_red_side(es_data)
    return {} unless es_data

    es_data['red_side_tendencies'] || es_data[:red_side_tendencies] || {}
  end
end
