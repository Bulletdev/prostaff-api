# frozen_string_literal: true

module Competitive
  module Services
    # Imports professional match data from the ProStaff Scraper into CompetitiveMatch records.
    #
    # The scraper returns match documents indexed from LoL Esports (schedule) and enriched
    # via Leaguepedia (per-player stats: champion, KDA, items, runes, summoner spells).
    # Only `riot_enriched: true` matches contain participant data and are imported.
    #
    # @example Import CBLOL matches for a specific org team
    #   service = Competitive::Services::ScraperImporterService.new(organization)
    #   result  = service.import_batch(matches, our_team: 'paiN Gaming')
    #   # => { imported: 5, skipped_duplicate: 3, skipped_unenriched: 2, errors: 0 }
    #
    class ScraperImporterService
      # Leaguepedia role values mapped to our internal lowercase convention
      ROLE_MAP = {
        'Top' => 'top',
        'Jungle' => 'jungle',
        'Mid' => 'mid',
        'Bot' => 'adc',
        'Support' => 'support'
      }.freeze

      # Derive broad tournament region from league slug
      LEAGUE_REGION = {
        'CBLOL' => 'BR',
        'LCS' => 'NA',
        'LEC' => 'EUW',
        'LCK' => 'KR',
        'LPL' => 'CN',
        'LLA' => 'LATAM',
        'PCS' => 'SEA',
        'VCS' => 'VCS',
        'TCL' => 'TR',
        'LJL' => 'JP',
        'CBLOL_A' => 'BR'
      }.freeze

      def initialize(organization)
        @organization = organization
      end

      # Import an array of match hashes returned by ProStaffScraperService#fetch_matches.
      #
      # @param matches  [Array<Hash>]  raw match hashes from the scraper API
      # @param our_team [String, nil]  the org's team name as listed in Leaguepedia
      #                                (e.g. 'paiN Gaming'). If nil, team1 is used as
      #                                our_team and victory is left unknown.
      # @return [Hash] import statistics
      def import_batch(matches, our_team: nil)
        stats = {
          imported: 0,
          skipped_duplicate: 0,
          skipped_unenriched: 0,
          skipped_not_our_game: 0,
          errors: 0
        }

        matches.each do |match|
          import_one(match, our_team, stats)
        end

        stats
      end

      private

      def import_one(match, our_team, stats)
        unless match['riot_enriched']
          stats[:skipped_unenriched] += 1
          return
        end

        # When our_team is specified, skip matches where the org's team did not participate.
        # Without this guard, ALL tournament games would be imported with a random team
        # labeled as "ours" (the resolve_teams fallback to team1).
        if our_team.present?
          team1 = match.dig('team1', 'name').to_s
          team2 = match.dig('team2', 'name').to_s
          unless teams_match?(team1, our_team) || teams_match?(team2, our_team)
            stats[:skipped_not_our_game] += 1
            return
          end
        end

        ext_id = build_external_match_id(match)

        if @organization.competitive_matches.exists?(external_match_id: ext_id)
          stats[:skipped_duplicate] += 1
          return
        end

        CompetitiveMatch.create!(build_attributes(match, ext_id, our_team))
        stats[:imported] += 1
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "[ScraperImporter] Validation failed for #{ext_id}: #{e.message}"
        stats[:errors] += 1
      rescue StandardError => e
        Rails.logger.error "[ScraperImporter] Unexpected error for #{ext_id}: #{e.message}"
        stats[:errors] += 1
      end

      def build_attributes(match, ext_id, our_team)
        team1_name = match.dig('team1', 'name').to_s
        team2_name = match.dig('team2', 'name').to_s
        win_team   = match['win_team'].to_s
        league     = match['league'].to_s

        our_resolved, opp_resolved = resolve_teams(team1_name, team2_name, win_team, our_team)

        {
          organization: @organization,
          tournament_name: league,
          tournament_stage: match['stage'],
          tournament_region: LEAGUE_REGION[league],
          external_match_id: ext_id,
          match_date: parse_date(match['start_time']),
          game_number: match['game_number'],
          patch_version: match['patch'],
          vod_url: build_vod_url(match['vod_youtube_id']),
          our_team_name: our_resolved,
          opponent_team_name: opp_resolved,
          victory: determine_victory(our_resolved, win_team),
          # In Leaguepedia/LoL Esports convention, team1 is always blue side.
          side: derive_side(our_resolved, team1_name),
          our_picks: build_picks(match['participants'], our_resolved),
          opponent_picks: build_picks(match['participants'], opp_resolved),
          game_stats: build_game_stats(match, team1_name, team2_name)
        }
      end

      # Returns [our_team_name, opponent_team_name] resolved from the match.
      # If our_team is nil, team1 is used as ours (victory stays nil).
      def resolve_teams(team1_name, team2_name, _win_team, our_team)
        return [team1_name, team2_name] if our_team.blank?

        if teams_match?(team1_name, our_team)
          [team1_name, team2_name]
        elsif teams_match?(team2_name, our_team)
          [team2_name, team1_name]
        else
          Rails.logger.warn(
            "[ScraperImporter] our_team '#{our_team}' did not match " \
            "'#{team1_name}' or '#{team2_name}' — defaulting to team1"
          )
          [team1_name, team2_name]
        end
      end

      # Case-insensitive partial match to handle accent differences
      # (e.g. "LEVIATÁN" vs "Leviatan" in Leaguepedia's utf8_unicode_ci collation).
      def teams_match?(team_name, candidate)
        return false if team_name.blank? || candidate.blank?

        t = team_name.downcase.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '')
        c = candidate.downcase.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '')
        t == c || t.include?(c) || c.include?(t)
      end

      def determine_victory(our_team_name, win_team)
        return nil if our_team_name.blank? || win_team.blank?

        teams_match?(our_team_name, win_team)
      end

      # Map participants belonging to a given team into pick hashes.
      # Returns [] if participants are nil or team name is blank.
      def build_picks(participants, team_name)
        return [] if participants.blank? || team_name.blank?

        participants
          .select { |p| teams_match?(p['team_name'].to_s, team_name) }
          .map do |p|
            {
              'champion' => p['champion_name'],
              'role' => normalize_role(p['role']),
              'summoner_name' => p['summoner_name'],
              'kills' => p['kills'],
              'deaths' => p['deaths'],
              'assists' => p['assists'],
              'win' => p['win']
            }.compact
          end
      end

      def normalize_role(role)
        ROLE_MAP[role] || role&.downcase || 'unknown'
      end

      # Store the full enriched data for analytics — participants with all stats,
      # plus game-level metadata from Leaguepedia. team1_name/team2_name are stored
      # so that side can be retroactively derived (team1 = blue side convention).
      def build_game_stats(match, team1_name = nil, team2_name = nil)
        {
          'source' => 'prostaff_scraper',
          'enrichment_source' => match['enrichment_source'],
          'leaguepedia_page' => match['leaguepedia_page'],
          'gamelength' => match['gamelength'],
          'game_duration_seconds' => match['game_duration_seconds'],
          'win_team' => match['win_team'],
          'team1_name' => team1_name.presence || match.dig('team1', 'name'),
          'team2_name' => team2_name.presence || match.dig('team2', 'name'),
          'participants' => match['participants'] || []
        }.compact
      end

      # Derive our side from team1/team2 assignment.
      # In Leaguepedia and LoL Esports data, team1 is always blue side, team2 is red.
      # Returns nil when either name is missing (e.g. no our_team provided).
      def derive_side(our_team_name, team1_name)
        return nil if our_team_name.blank? || team1_name.blank?

        teams_match?(our_team_name, team1_name) ? 'blue' : 'red'
      end

      def build_external_match_id(match)
        "#{match['match_id']}_#{match['game_number']}"
      end

      def build_vod_url(youtube_id)
        return nil if youtube_id.blank?

        "https://www.youtube.com/watch?v=#{youtube_id}"
      end

      def parse_date(raw)
        return nil if raw.blank?

        Time.zone.parse(raw)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
