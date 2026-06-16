# frozen_string_literal: true

module MetaIntelligence
  # Materializes Oracle's Elixir tournament stats (teams + players) from the
  # scraper's local cache into tournament_team_stats and tournament_player_stats.
  #
  # Reads the scraper's /analytics/tournament-stats/index to discover which
  # tournaments are cached, then upserts each one.  Idempotent — re-running
  # overwrites with the latest data.
  #
  # If the OE downloader hasn't run yet for a league, the index returns empty
  # and the job exits cleanly without error.
  #
  # @example Enqueue for CBLOL after a historical backfill
  #   MetaIntelligence::SyncTournamentStatsJob.perform_later('CBLOL')
  #
  # @example Enqueue for a specific year only
  #   MetaIntelligence::SyncTournamentStatsJob.perform_later('CBLOL', year: 2026)
  #
  class SyncTournamentStatsJob < ApplicationJob
    queue_as :meta_intelligence

    retry_on ProStaffScraperService::UnavailableError, wait: 5.minutes, attempts: 3

    # @param league [String] e.g. 'CBLOL', 'LCS'
    # @param year   [Integer, nil] optional — only sync tournaments from this year
    def perform(league, year: nil)
      Rails.logger.info(
        "[SyncTournamentStatsJob] starting — league=#{league} year=#{year || 'all'}"
      )

      scraper = ProStaffScraperService.new
      by_tournament = discover_tournaments(scraper, league, year)

      if by_tournament.empty?
        Rails.logger.warn(
          "[SyncTournamentStatsJob] nothing to sync for league=#{league} year=#{year || 'all'}"
        )
        return
      end

      total_teams   = 0
      total_players = 0
      by_tournament.each do |tid, meta|
        t, p = sync_tournament(scraper, tid, meta)
        total_teams   += t
        total_players += p
      end

      Rails.logger.info(
        "[SyncTournamentStatsJob] complete — league=#{league} " \
        "teams_upserted=#{total_teams} players_upserted=#{total_players}"
      )
    end

    # Prefixes confirmed by audit of 11,661 OE names (2014–2026, executed 2026-06-14)
    # to cause false merges with major-league bare names. SHA Aki (LIT 2026) collides
    # with Aki (LPL 2025) — the only active case without a min_year mitigation.
    # When check_normalization_collisions logs a new collision: add the prefix here.
    TEAM_PREFIX_DENYLIST = %w[SHA].freeze

    private

    # Query the scraper index and group entries by tournament_id.
    # Returns {} if nothing is cached or tournament_id is missing.
    def discover_tournaments(scraper, league, year)
      index   = scraper.fetch_tournament_stats_index(league: league, year: year)
      entries = index['entries'] || []

      if entries.empty?
        Rails.logger.warn(
          '[SyncTournamentStatsJob] no cached tournaments — ' \
          'run etl/oe_stats_downloader.py first'
        )
        return {}
      end

      grouped = entries.each_with_object({}) do |e, h|
        tid = e['tournament_id']
        next if tid.blank?

        h[tid] ||= { league: e['league'], year: e['year'].to_i, types: [] }
        h[tid][:types] << e['stat_type']
      end

      if grouped.empty?
        Rails.logger.warn(
          '[SyncTournamentStatsJob] index entries lack tournament_id — ' \
          'deploy the latest scraper and re-run oe_stats_downloader.py'
        )
      end

      grouped
    end

    # Sync both stat types for one tournament. Returns [teams_count, players_count].
    def sync_tournament(scraper, tournament_id, meta)
      teams   = meta[:types].include?('teams') ? sync_type(scraper, tournament_id, 'teams', meta) : 0
      players = meta[:types].include?('players') ? sync_type(scraper, tournament_id, 'players', meta) : 0
      [teams, players]
    end

    # Fetch one stat type for a tournament and upsert into the appropriate table.
    # Returns the number of rows upserted (0 on empty or error).
    def sync_type(scraper, tournament_id, type, meta)
      result = scraper.fetch_tournament_stats(tournament: tournament_id, type: type)
      rows   = result['data'] || []
      return 0 if rows.empty?

      now = Time.current.utc
      if type == 'teams'
        upsert_teams(tournament_id, meta[:league], meta[:year], rows, now)
      else
        upsert_players(tournament_id, meta[:league], meta[:year], rows, now)
      end
    rescue ProStaffScraperService::NotFoundError
      Rails.logger.warn(
        "[SyncTournamentStatsJob] #{type} not cached for '#{tournament_id}' — skipping"
      )
      0
    rescue ProStaffScraperService::ScraperError => e
      Rails.logger.error(
        "[SyncTournamentStatsJob] error fetching #{type} for '#{tournament_id}': #{e.message}"
      )
      0
    end

    def upsert_teams(tournament_id, league, year, rows, now)
      records = rows.filter_map do |row|
        team_name = pick(row, 'team', 'Team', 'teamName')
        next if team_name.blank?

        { tournament_id: tournament_id, team_name: team_name, league: league,
          year: year, data: row, computed_at: now, created_at: now, updated_at: now }
      end

      records = records.uniq { |r| [r[:tournament_id], r[:team_name]] }
      return 0 if records.empty?

      TournamentTeamStat.upsert_all(
        records,
        unique_by: :uq_tournament_team_stats,
        update_only: %i[data computed_at]
      )
      records.size
    end

    def upsert_players(tournament_id, league, year, rows, now)
      records = rows.filter_map do |row|
        raw_name    = pick(row, 'player', 'Player', 'playerName')
        player_name = normalize_player_name(raw_name)
        next if player_name.blank?

        { tournament_id: tournament_id, player_name: player_name,
          raw_player_name: raw_name,
          league: league, year: year,
          team_name: pick(row, 'team', 'Team', 'teamName'),
          position: pick(row, 'pos', 'Pos', 'position', 'role', 'Position'),
          data: row, computed_at: now, created_at: now, updated_at: now }
      end

      records = records.uniq { |r| [r[:tournament_id], r[:player_name]] }
      return 0 if records.empty?

      check_normalization_collisions(records)

      TournamentPlayerStat.upsert_all(
        records,
        unique_by: :uq_tournament_player_stats,
        update_only: %i[raw_player_name team_name position data computed_at]
      )
      records.size
    end

    # Return the first non-blank value for any of the given keys from a hash.
    def pick(hash, *keys)
      keys.each { |k| return hash[k] if hash[k].present? }
      nil
    end

    def normalize_player_name(name)
      return name if name.blank?

      parts = name.strip.split
      return name unless parts.length >= 2

      prefix = parts.first
      return name unless prefix.length.between?(2, 5) && prefix == prefix.upcase
      return name if TEAM_PREFIX_DENYLIST.include?(prefix)

      parts[1..].join(' ')
    end

    def check_normalization_collisions(records)
      normalized = records.reject { |r| r[:raw_player_name] == r[:player_name] }
      return if normalized.empty?

      normalized_names = normalized.map { |r| r[:player_name] }

      existing_bare = TournamentPlayerStat
                      .where(player_name: normalized_names)
                      .where('raw_player_name = player_name OR raw_player_name IS NULL')
                      .pluck(:player_name, :league, :year)

      return if existing_bare.empty?

      existing_map = existing_bare.group_by(&:first)

      normalized.each do |r|
        next unless existing_map.key?(r[:player_name])

        prefix = r[:raw_player_name].split(' ', 2).first
        next if TEAM_PREFIX_DENYLIST.include?(prefix)

        collisions = existing_map[r[:player_name]]
        Rails.logger.warn(
          '[SyncTournamentStatsJob] NORMALIZATION_COLLISION: ' \
          "raw=#{r[:raw_player_name].inspect} normalized to #{r[:player_name].inspect} " \
          "collides with existing bare-name rows: #{collisions.map { |_, lg, yr| "#{lg}/#{yr}" }.join(', ')}. " \
          "Add #{prefix.inspect} to TEAM_PREFIX_DENYLIST if these are different people."
        )
      end
    end
  end
end
