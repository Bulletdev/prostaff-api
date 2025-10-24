# frozen_string_literal: true

module Competitive
  module Utilities
    # Pure utility methods for draft analysis calculations
    # All methods are stateless and can be called as module functions
    #
    # @example
    #   Competitive::Utilities::DraftAnalyzer.calculate_meta_score(picks, patch)
    module DraftAnalyzer
      extend self

      # Calculate how "meta" a composition is (0-100)
      #
      # @param picks [Array<String>] Champion names
      # @param patch [String, nil] Patch version
      # @return [Float] Meta score (0-100)
      def calculate_meta_score(picks, patch)
        return 0 if picks.blank?

        # Get recent pro matches
        recent_matches = CompetitiveMatch.recent(14).limit(100)
        recent_matches = recent_matches.by_patch(patch) if patch.present?

        return 0 if recent_matches.empty?

        # Count how many times each champion appears
        all_picks = recent_matches.flat_map(&:our_picked_champions)
        pick_frequency = all_picks.tally

        # Score our picks based on how popular they are
        score = picks.sum do |champion|
          frequency = pick_frequency[champion] || 0
          (frequency.to_f / recent_matches.size) * 100
        end

        # Average and cap at 100
        [(score / picks.size).round(2), 100].min
      end

      # Calculate similarity score between user's picks and similar matches
      #
      # @param picks [Array<String>] User's champion picks
      # @param similar_matches [Array<CompetitiveMatch>] Similar matches
      # @return [Float] Average similarity score (0-100)
      def calculate_similarity_score(picks, similar_matches)
        return 0 if similar_matches.empty?

        scores = similar_matches.map do |match|
          common = (picks & match.our_picked_champions).size
          (common.to_f / picks.size) * 100
        end

        (scores.sum / scores.size).round(2)
      end

      # Generate strategic insights based on analysis
      #
      # @param our_picks [Array<String>] User's picks (reserved for future use)
      # @param opponent_picks [Array<String>] Opponent's picks
      # @param our_bans [Array<String>] User's bans
      # @param similar_matches [Array<CompetitiveMatch>] Similar matches
      # @param meta_score [Float] Meta score
      # @param patch [String, nil] Patch version
      # @return [Array<String>] Array of insight messages
      def generate_insights(_our_picks:, opponent_picks:, our_bans:, similar_matches:, meta_score:, patch:)
        insights = []

        # Meta relevance
        insights << meta_relevance_message(meta_score)

        # Similar matches performance
        insights.concat(similar_matches_insights(similar_matches)) if similar_matches.any?

        # Synergy check (placeholder - can be enhanced)
        insights << '💡 Analise sinergia entre seus picks antes do jogo começar'

        # Patch relevance
        insights << patch_relevance_message(patch)

        insights
      end

      # Format match for API response
      #
      # @param match [CompetitiveMatch] Match to format
      # @return [Hash] Formatted match data
      def format_match(match)
        {
          id: match.id,
          tournament: match.tournament_display,
          date: match.match_date,
          result: match.result_text,
          our_picks: match.our_picked_champions,
          opponent_picks: match.opponent_picked_champions,
          patch: match.patch_version
        }
      end

      # Calculate pick frequency and rate
      #
      # @param picks [Array<String>] Champion picks
      # @return [Array<Hash>] Top 10 picks with frequencies
      def calculate_pick_frequency(picks)
        return [] if picks.empty?

        picks.tally.sort_by { |_k, v| -v }.first(10).map do |champion, count|
          {
            champion: champion,
            picks: count,
            pick_rate: ((count.to_f / picks.size) * 100).round(2)
          }
        end
      end

      # Calculate ban frequency and rate
      #
      # @param bans [Array<String>] Champion bans
      # @return [Array<Hash>] Top 10 bans with frequencies
      def calculate_ban_frequency(bans)
        return [] if bans.empty?

        bans.tally.sort_by { |_k, v| -v }.first(10).map do |champion, count|
          {
            champion: champion,
            bans: count,
            ban_rate: ((count.to_f / bans.size) * 100).round(2)
          }
        end
      end

      # Extract all bans from a match
      #
      # @param match [CompetitiveMatch] Match to extract bans from
      # @return [Array<String>] All banned champions
      def extract_bans(match)
        match.our_banned_champions + match.opponent_banned_champions
      end

      # Extract picks for a specific role from a match
      #
      # @param match [CompetitiveMatch] Match to extract from
      # @param role [String] Role to filter by
      # @return [Array<String>] Champion picks for the role
      def extract_role_picks(match, role)
        picks_for_role = []

        our_pick = match.our_picks.find { |p| p['role']&.downcase == role.downcase }
        picks_for_role << our_pick['champion'] if our_pick && our_pick['champion']

        opponent_pick = match.opponent_picks.find { |p| p['role']&.downcase == role.downcase }
        picks_for_role << opponent_pick['champion'] if opponent_pick && opponent_pick['champion']

        picks_for_role
      end

      # Build meta analysis response with pick/ban frequencies
      #
      # @param role [String] Role analyzed
      # @param patch [String] Patch version
      # @param picks [Array<String>] All picks
      # @param bans [Array<String>] All bans
      # @param total_matches [Integer] Total matches analyzed
      # @return [Hash] Meta analysis response
      def build_meta_analysis_response(role, patch, picks, bans, total_matches)
        {
          role: role,
          patch: patch,
          top_picks: calculate_pick_frequency(picks),
          top_bans: calculate_ban_frequency(bans),
          total_matches: total_matches
        }
      end

      private

      # Generate meta relevance insight message
      #
      # @param meta_score [Float] Meta score
      # @return [String] Insight message
      def meta_relevance_message(meta_score)
        if meta_score >= 70
          "✅ Composição altamente meta (#{meta_score}% alinhada com picks profissionais)"
        elsif meta_score >= 40
          "⚠️ Composição moderadamente meta (#{meta_score}% alinhada)"
        else
          "❌ Composição off-meta (#{meta_score}% alinhada). Considere picks mais populares."
        end
      end

      # Generate insights from similar matches
      #
      # @param similar_matches [Array<CompetitiveMatch>] Similar matches
      # @return [Array<String>] Insight messages
      def similar_matches_insights(similar_matches)
        insights = []
        winrate = ((similar_matches.count(&:victory?).to_f / similar_matches.size) * 100).round(0)

        if winrate >= 60
          insights << "🏆 Composições similares têm #{winrate}% de winrate em jogos profissionais"
        elsif winrate <= 40
          insights << "⚠️ Composições similares têm apenas #{winrate}% de winrate"
        end

        insights
      end

      # Generate patch relevance insight message
      #
      # @param patch [String, nil] Patch version
      # @return [String] Insight message
      def patch_relevance_message(patch)
        if patch.present?
          "📊 Análise baseada no patch #{patch}"
        else
          '⚠️ Análise cross-patch - considere o patch atual para maior precisão'
        end
      end
    end
  end
end
