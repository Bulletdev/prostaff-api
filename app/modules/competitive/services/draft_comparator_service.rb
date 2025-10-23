# frozen_string_literal: true

module Competitive
  module Services
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
        meta_score = calculate_meta_score(our_picks, patch)

        # Generate insights
        insights = generate_insights(
          our_picks: our_picks,
          opponent_picks: opponent_picks,
          our_bans: our_bans,
          similar_matches: similar_matches,
          meta_score: meta_score,
          patch: patch
        )

        {
          similarity_score: calculate_similarity_score(our_picks, similar_matches),
          similar_matches: similar_matches.map { |m| format_match(m) },
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
        matches = CompetitiveMatch.recent(30)
        matches = matches.by_patch(patch) if patch.present?

        picks = []
        bans = []

        matches.each do |match|
          # Extract picks for this role
          our_pick = match.our_picks.find { |p| p['role']&.downcase == role.downcase }
          picks << our_pick['champion'] if our_pick && our_pick['champion']

          opponent_pick = match.opponent_picks.find { |p| p['role']&.downcase == role.downcase }
          picks << opponent_pick['champion'] if opponent_pick && opponent_pick['champion']

          # Extract bans (bans don't have roles, so we count all)
          bans += match.our_banned_champions
          bans += match.opponent_banned_champions
        end

        # Count frequencies
        pick_frequency = picks.tally.sort_by { |_k, v| -v }.first(10)
        ban_frequency = bans.tally.sort_by { |_k, v| -v }.first(10)

        {
          role: role,
          patch: patch,
          top_picks: pick_frequency.map do |champion, count|
            {
              champion: champion,
              picks: count,
              pick_rate: ((count.to_f / picks.size) * 100).round(2)
            }
          end,
          top_bans: ban_frequency.map do |champion, count|
            {
              champion: champion,
              bans: count,
              ban_rate: ((count.to_f / bans.size) * 100).round(2)
            }
          end,
          total_matches: matches.size
        }
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

      # Calculate how "meta" a composition is (0-100)
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
      def calculate_similarity_score(picks, similar_matches)
        return 0 if similar_matches.empty?

        scores = similar_matches.map do |match|
          common = (picks & match.our_picked_champions).size
          (common.to_f / picks.size) * 100
        end

        (scores.sum / scores.size).round(2)
      end

      # Generate strategic insights based on analysis
      # Note: our_picks parameter reserved for future use
      def generate_insights(_our_picks:, opponent_picks:, our_bans:, similar_matches:, meta_score:, patch:)
        insights = []

        # Meta relevance
        insights << if meta_score >= 70
                      "✅ Composição altamente meta (#{meta_score}% alinhada com picks profissionais)"
                    elsif meta_score >= 40
                      "⚠️ Composição moderadamente meta (#{meta_score}% alinhada)"
                    else
                      "❌ Composição off-meta (#{meta_score}% alinhada). Considere picks mais populares."
                    end

        # Similar matches performance
        if similar_matches.any?
          winrate = ((similar_matches.count(&:victory?).to_f / similar_matches.size) * 100).round(0)
          if winrate >= 60
            insights << "🏆 Composições similares têm #{winrate}% de winrate em jogos profissionais"
          elsif winrate <= 40
            insights << "⚠️ Composições similares têm apenas #{winrate}% de winrate"
          end
        end

        # Synergy check (placeholder - can be enhanced)
        insights << '💡 Analise sinergia entre seus picks antes do jogo começar'

        # Patch relevance
        insights << if patch.present?
                      "📊 Análise baseada no patch #{patch}"
                    else
                      '⚠️ Análise cross-patch - considere o patch atual para maior precisão'
                    end

        insights
      end

      # Format match for API response
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
    end
  end
end
