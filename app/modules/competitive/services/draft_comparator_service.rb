# frozen_string_literal: true

module Competitive
  module Services
    # Service for comparing draft compositions with professional meta data
    # Delegates pure calculations to Competitive::Utilities::DraftAnalyzer
    #
    # This service provides draft analysis by comparing user compositions
    # against professional match data, including:
    # - Finding similar professional matches
    # - Calculating composition winrates
    # - Meta score analysis (alignment with pro picks)
    # - Strategic insights and counter-pick suggestions
    #
    # @example Compare a draft
    #   DraftComparatorService.compare_draft(
    #     our_picks: ['Aatrox', 'Lee Sin', 'Orianna', 'Jinx', 'Thresh'],
    #     opponent_picks: ['Gnar', 'Graves', 'Sylas', 'Kai\'Sa', 'Nautilus'],
    #     our_bans: ['Akali', 'Azir', 'Lucian'],
    #     patch: '14.20',
    #     organization: current_org
    #   )
    #
    class DraftComparatorService
      # Compare user's draft with professional meta data
      # @param our_picks [Array<String>] Array of champion names
      # @param opponent_picks [Array<String>] Array of champion names
      # @param our_bans [Array<String>] Array of banned champion names
      # @param opponent_bans [Array<String>] Array of banned champion names
      # @param patch [String] Patch version (e.g., '14.20')
      # @param organization [Organization] User's organization for scope
      # @return [Hash] Comparison results with insights
      def self.compare_draft(our_picks:, opponent_picks:, organization:, our_bans: [], opponent_bans: [], patch: nil)
        new.compare_draft(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          our_bans: our_bans,
          opponent_bans: opponent_bans,
          patch: patch,
          organization: organization
        )
      end

      # NOTE: opponent_bans parameter reserved for future ban analysis
      def compare_draft(our_picks:, opponent_picks:, our_bans:, _opponent_bans:, patch:, organization:)
        # Find similar professional matches
        similar_matches = find_similar_matches(
          champions: our_picks,
          patch: patch,
          limit: 10
        )

        # Calculate composition winrate
        winrate = composition_winrate(
          champions: our_picks,
          patch: patch
        )

        # Calculate meta score (how aligned with pro meta)
        meta_score = analyzer.calculate_meta_score(our_picks, patch)

        # Generate insights
        insights = analyzer.generate_insights(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          our_bans: our_bans,
          similar_matches: similar_matches,
          meta_score: meta_score,
          patch: patch
        )

        {
          similarity_score: analyzer.calculate_similarity_score(our_picks, similar_matches),
          similar_matches: similar_matches.map { |m| analyzer.format_match(m) },
          composition_winrate: winrate,
          meta_score: meta_score,
          insights: insights,
          patch: patch,
          analyzed_at: Time.current
        }
      end

      # Find professional matches with similar champion compositions
      # @param champions [Array<String>] Champion names to match
      # @param patch [String] Patch version
      # @param limit [Integer] Max number of matches to return
      # @return [Array<CompetitiveMatch>] Similar matches from database
      def find_similar_matches(champions:, patch:, limit: 10)
        return [] if champions.blank?

        # Find matches where at least 3 of our champions were picked
        matches = CompetitiveMatch
                  .where.not(our_picks: nil)
                  .where.not(our_picks: [])
                  .limit(limit * 3) # Get more for filtering

        # Filter by patch if provided
        matches = matches.by_patch(patch) if patch.present?

        # Score and sort by similarity
        scored_matches = matches.map do |match|
          picked_champions = match.our_picked_champions
          common_champions = (champions & picked_champions).size
          {
            match: match,
            similarity: common_champions.to_f / champions.size
          }
        end

        # Return top matches sorted by similarity
        scored_matches
          .sort_by { |m| -m[:similarity] }
          .select { |m| m[:similarity] >= 0.3 } # At least 30% similar
          .first(limit)
          .map { |m| m[:match] }
      end

      # Calculate winrate of a specific composition in professional play
      # @param champions [Array<String>] Champion names
      # @param patch [String] Patch version
      # @return [Float] Winrate percentage (0-100)
      def composition_winrate(champions:, patch:)
        return 0.0 if champions.blank?

        matches = find_similar_matches(champions: champions, patch: patch, limit: 50)
        return 0.0 if matches.empty?

        victories = matches.count(&:victory?)
        ((victories.to_f / matches.size) * 100).round(2)
      end

      # Analyze meta picks by role
      # @param role [String] Role (top, jungle, mid, adc, support)
      # @param patch [String] Patch version
      # @return [Hash] Top picks and bans for the role
      def meta_analysis(role:, patch:)
        matches = fetch_matches_for_meta(patch)
        picks, bans = extract_picks_and_bans(matches, role)

        analyzer.build_meta_analysis_response(role, patch, picks, bans, matches.size)
      end

      # Suggest counter picks based on professional data
      # @param opponent_pick [String] Enemy champion
      # @param role [String] Role
      # @param patch [String] Patch version
      # @return [Array<Hash>] Suggested counters with winrate
      def suggest_counters(opponent_pick:, role:, patch:)
        # Find matches where opponent_pick was played
        matches = CompetitiveMatch.recent(30)
        matches = matches.by_patch(patch) if patch.present?

        counters = Hash.new { |h, k| h[k] = { wins: 0, total: 0 } }

        matches.each do |match|
          # Check if opponent picked this champion in this role
          opponent_champion = match.opponent_picks.find do |p|
            p['champion'] == opponent_pick && p['role']&.downcase == role.downcase
          end

          next unless opponent_champion

          # Find what was picked against it in same role
          our_champion = match.our_picks.find { |p| p['role']&.downcase == role.downcase }
          next unless our_champion && our_champion['champion']

          counter_name = our_champion['champion']
          counters[counter_name][:total] += 1
          counters[counter_name][:wins] += 1 if match.victory?
        end

        # Calculate winrates and sort
        counters.map do |champion, stats|
          {
            champion: champion,
            games: stats[:total],
            winrate: ((stats[:wins].to_f / stats[:total]) * 100).round(2)
          }
        end.sort_by { |c| -c[:winrate] }.first(5)
      end

      private

      # Returns the analyzer utility module
      def analyzer
        @analyzer ||= Competitive::Utilities::DraftAnalyzer
      end

      # Fetch matches for meta analysis
      def fetch_matches_for_meta(patch)
        matches = CompetitiveMatch.recent(30)
        patch.present? ? matches.by_patch(patch) : matches
      end

      # Extract picks and bans from matches for a specific role
      def extract_picks_and_bans(matches, role)
        picks = []
        bans = []

        matches.each do |match|
          picks.concat(analyzer.extract_role_picks(match, role))
          bans.concat(analyzer.extract_bans(match))
        end

        [picks, bans]
      end
    end
  end
end
