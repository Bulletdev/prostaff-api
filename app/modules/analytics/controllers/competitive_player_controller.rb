# frozen_string_literal: true

module Analytics
  module Controllers
    # Competitive Player Analytics Controller
    #
    # Aggregates individual performance stats from professional/competitive matches
    # stored in CompetitiveMatch#our_picks. Useful for analysing how a specific
    # player performed across tournaments without querying Elasticsearch.
    #
    # Picks are extended with the full stat set after Fix-2; older records may
    # have only the 7-field format — run `rake competitive:backfill_picks` first.
    #
    # @example
    #   GET /api/v1/analytics/competitive/player-stats?summoner_name=brTT&league=CBLOL&year=2025
    #
    # Query parameters (all optional):
    #   summoner_name  — exact match against picks' summoner_name (required)
    #   league         — filter by tournament_name (e.g. "CBLOL")
    #   year           — filter by match_date year (integer)
    #   include_opponent — also search opponent_picks (default: false)
    #
    class CompetitivePlayerController < Api::V1::BaseController
      def player_stats
        summoner_name = params[:summoner_name].to_s.strip
        return render_error('summoner_name is required', :bad_request) if summoner_name.blank?

        matches = scoped_matches(summoner_name)
        return render_success(empty_response(summoner_name)) if matches.empty?

        player_picks = extract_picks(matches, summoner_name)
        return render_success(empty_response(summoner_name)) if player_picks.empty?

        render_success({
                         summoner_name: summoner_name,
                         games_played: player_picks.size,
                         overall: build_overall_stats(player_picks),
                         by_tournament: build_by_tournament(matches, summoner_name),
                         champion_pool: build_champion_pool(player_picks),
                         recent_games: build_recent_games(player_picks, matches)
                       })
      end

      private

      # ---------------------------------------------------------------------------
      # Data retrieval
      # ---------------------------------------------------------------------------

      def scoped_matches(summoner_name)
        # JSONB containment: find matches where our_picks (or opponent_picks)
        # contains at least one element with the given summoner_name.
        pick_filter = [{ 'summoner_name' => summoner_name }].to_json

        scope = CompetitiveMatch
                .where(organization: current_organization)
                .where('our_picks @> ?', pick_filter)

        if params[:include_opponent].to_s == 'true'
          scope = scope.or(
            CompetitiveMatch
              .where(organization: current_organization)
              .where('opponent_picks @> ?', pick_filter)
          )
        end

        scope = scope.where(tournament_name: params[:league]) if params[:league].present?
        scope = scope.where('EXTRACT(YEAR FROM match_date) = ?', params[:year].to_i) if params[:year].present?

        scope.order(match_date: :desc)
      end

      # Flatten picks from all matches into a single array, annotating each
      # pick with match metadata for context (date, victory, tournament).
      def extract_picks(matches, summoner_name)
        matches.flat_map do |m|
          pick = find_pick_in_match(m, summoner_name)
          next unless pick

          pick.merge(
            '_match_id' => m.id,
            '_match_date' => m.match_date,
            '_victory' => m.victory,
            '_tournament_name' => m.tournament_name,
            '_tournament_stage' => m.tournament_stage
          )
        end.compact
      end

      def find_pick_in_match(match, summoner_name)
        match.our_picks.find { |p| p['summoner_name']&.casecmp?(summoner_name) } ||
          (if params[:include_opponent].to_s == 'true'
             match.opponent_picks.find do |p|
               p['summoner_name']&.casecmp?(summoner_name)
             end
           end)
      end

      # ---------------------------------------------------------------------------
      # Aggregation helpers
      # ---------------------------------------------------------------------------

      def build_overall_stats(picks)
        games = picks.size
        wins  = picks.count { |p| p['win'] || p['_victory'] }

        {
          games: games,
          wins: wins,
          win_rate: pct(wins, games),
          avg_kills: avg(picks, 'kills'),
          avg_deaths: avg(picks, 'deaths'),
          avg_assists: avg(picks, 'assists'),
          avg_kda: compute_kda(picks),
          avg_cs: avg(picks, 'cs'),
          avg_gold: avg(picks, 'gold'),
          avg_damage: avg(picks, 'damage'),
          avg_damage_taken: avg(picks, 'damage_taken'),
          avg_vision_score: avg(picks, 'vision_score'),
          avg_wards_placed: avg(picks, 'wards_placed'),
          avg_wards_killed: avg(picks, 'wards_killed'),
          avg_cs_per_min: avg(picks, 'cs_per_min', round: 2),
          avg_gold_per_min: avg(picks, 'gold_per_min', round: 2),
          avg_damage_per_min: avg(picks, 'damage_per_min', round: 2)
        }
      end

      def build_by_tournament(matches, summoner_name)
        matches.group_by { |m| [m.tournament_name, m.tournament_stage] }.map do |(name, stage), group|
          picks = extract_picks(group, summoner_name)
          next if picks.empty?

          games = picks.size
          wins  = picks.count { |p| p['win'] || p['_victory'] }

          {
            tournament_name: name,
            tournament_stage: stage,
            games: games,
            wins: wins,
            win_rate: pct(wins, games),
            avg_kills: avg(picks, 'kills'),
            avg_deaths: avg(picks, 'deaths'),
            avg_assists: avg(picks, 'assists'),
            avg_kda: compute_kda(picks),
            avg_cs: avg(picks, 'cs'),
            avg_gold: avg(picks, 'gold'),
            avg_damage: avg(picks, 'damage'),
            champion_pool: build_champion_pool(picks)
          }
        end.compact
      end

      def build_champion_pool(picks)
        picks
          .group_by { |p| p['champion'] }
          .map do |champion, champ_picks|
            games = champ_picks.size
            wins  = champ_picks.count { |p| p['win'] || p['_victory'] }

            {
              champion: champion,
              games: games,
              wins: wins,
              win_rate: pct(wins, games),
              avg_kills: avg(champ_picks, 'kills'),
              avg_deaths: avg(champ_picks, 'deaths'),
              avg_assists: avg(champ_picks, 'assists'),
              avg_kda: compute_kda(champ_picks),
              avg_cs: avg(champ_picks, 'cs'),
              avg_damage: avg(champ_picks, 'damage')
            }
          end
          .sort_by { |c| -c[:games] }
      end

      def build_recent_games(picks, matches)
        match_map = matches.index_by(&:id)

        picks.first(20).map do |pick|
          m = match_map[pick['_match_id']]
          {
            match_id: pick['_match_id'],
            date: pick['_match_date'],
            tournament: pick['_tournament_name'],
            stage: pick['_tournament_stage'],
            champion: pick['champion'],
            role: pick['role'],
            kills: pick['kills'],
            deaths: pick['deaths'],
            assists: pick['assists'],
            cs: pick['cs'],
            gold: pick['gold'],
            damage: pick['damage'],
            vision_score: pick['vision_score'],
            items: pick['items'],
            victory: pick['win'] || pick['_victory'],
            our_team: m&.our_team_name,
            opponent_team: m&.opponent_team_name
          }
        end
      end

      # ---------------------------------------------------------------------------
      # Math helpers
      # ---------------------------------------------------------------------------

      def avg(picks, key, round: 1)
        values = picks.map { |p| p[key] }.compact
        return nil if values.empty?

        (values.sum.to_f / values.size).round(round)
      end

      def pct(numerator, denominator)
        return 0.0 if denominator.zero?

        ((numerator.to_f / denominator) * 100).round(1)
      end

      def compute_kda(picks)
        total_k = picks.sum { |p| p['kills'].to_f }
        total_d = picks.sum { |p| p['deaths'].to_f }
        total_a = picks.sum { |p| p['assists'].to_f }
        return nil if total_d.zero? && total_k.zero?

        denominator = total_d.zero? ? 1.0 : total_d
        ((total_k + total_a) / denominator).round(2)
      end

      def empty_response(summoner_name)
        {
          summoner_name: summoner_name,
          games_played: 0,
          overall: nil,
          by_tournament: [],
          champion_pool: [],
          recent_games: [],
          message: "No competitive matches found for '#{summoner_name}'"
        }
      end
    end
  end
end
