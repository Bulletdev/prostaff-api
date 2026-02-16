# frozen_string_literal: true

module Matches
  module Jobs
    class SyncMatchJob < ApplicationJob
      queue_as :default

      # retry_on RiotApiService::RateLimitError, wait: :polynomially_longer, attempts: 5
      # retry_on RiotApiService::RiotApiError, wait: 1.minute, attempts: 3

      def perform(match_id, organization_id, region = 'BR', force_update = false)
        puts "SyncMatchJob: Starting sync for #{match_id} (force_update: #{force_update})"
        $stdout.flush
        organization = Organization.find(organization_id)
        riot_service = RiotApiService.new

        begin
          match_data = riot_service.get_match_details(
            match_id: match_id,
            region: region
          )
        rescue Exception => e
          puts "SyncMatchJob: FATAL ERROR in get_match_details: #{e.class} - #{e.message}"
          puts e.backtrace.join("\n")
          $stdout.flush
          raise
        end
        puts 'SyncMatchJob: Match data fetched'
        $stdout.flush

        match = Match.find_by(riot_match_id: match_data[:match_id])
        if match.present?
          if force_update || needs_update?(match)
            puts 'SyncMatchJob: Match exists but needs update, updating...'
            $stdout.flush
            update_match_and_stats(match, match_data, organization)
          else
            puts 'SyncMatchJob: Match already exists and is up to date'
            $stdout.flush
            return
          end
        else
          match = create_match_record(match_data, organization)
          puts 'SyncMatchJob: Match record created'
          $stdout.flush
          create_player_match_stats(match, match_data[:participants], organization)
        end

        Rails.logger.info("Successfully synced match #{match_id}")
      rescue RiotApiService::NotFoundError => e
        Rails.logger.error("Match not found in Riot API: #{match_id} - #{e.message}")
      rescue StandardError => e
        Rails.logger.error("Failed to sync match #{match_id}: #{e.message}")
        raise
      end

      private

      # Check if match needs update (missing critical data)
      def needs_update?(match)
        # Check if any player stats are missing critical fields
        match.player_match_stats.any? do |stat|
          stat.cs.nil? || stat.cs.zero? ||
            stat.damage_share.nil? ||
            stat.gold_share.nil? ||
            stat.cs_per_min.nil?
        end
      end

      # Update existing match and stats
      def update_match_and_stats(match, match_data, organization)
        # Update match record if needed
        match.update!(
          game_duration: match_data[:game_duration],
          game_version: match_data[:game_version],
          match_type: determine_match_type(match_data[:game_mode], match_data[:participants], organization),
          victory: determine_team_victory(match_data[:participants], organization)
        )

        # Delete old stats and recreate with new data
        match.player_match_stats.destroy_all
        create_player_match_stats(match, match_data[:participants], organization)
        puts 'SyncMatchJob: Match and stats updated'
        $stdout.flush
      end

      def create_match_record(match_data, organization)
        Match.create!(
          organization: organization,
          riot_match_id: match_data[:match_id],
          match_type: determine_match_type(match_data[:game_mode], match_data[:participants], organization),
          game_start: match_data[:game_creation],
          game_end: match_data[:game_creation] + match_data[:game_duration].seconds,
          game_duration: match_data[:game_duration],
          game_version: match_data[:game_version],
          victory: determine_team_victory(match_data[:participants], organization)
        )
      end

      def create_player_match_stats(match, participants, organization)
        puts "SyncMatchJob: Creating player stats for #{participants.size} participants"

        # Determine if this is a competitive match (5+ org players) or solo queue (1 org player)
        our_player_puuids = organization.players.pluck(:riot_puuid).compact
        our_participants = participants.select { |p| our_player_puuids.include?(p[:puuid]) }
        is_competitive = our_participants.size >= 5

        puts "SyncMatchJob: Match type: #{is_competitive ? 'Competitive (team)' : 'Solo Queue'}"
        puts "SyncMatchJob: Our players in match: #{our_participants.size}"

        # Calculate team totals for shares
        # For competitive: use only our organization's players
        # For solo queue: use all players on the same team
        team_totals = if is_competitive
                        # Competitive: calculate shares among org players only
                        our_participants.group_by { |p| p[:team_id] }.transform_values do |team_participants|
                          {
                            total_damage: team_participants.sum { |p| p[:total_damage_dealt] }.to_f,
                            total_gold: team_participants.sum { |p| p[:gold_earned] }.to_f,
                            total_cs: team_participants.sum { |p| (p[:minions_killed] || 0) + (p[:neutral_minions_killed] || 0) }.to_f
                          }
                        end
                      else
                        # Solo queue: calculate shares among all team members
                        participants.group_by { |p| p[:team_id] }.transform_values do |team_participants|
                          {
                            total_damage: team_participants.sum { |p| p[:total_damage_dealt] }.to_f,
                            total_gold: team_participants.sum { |p| p[:gold_earned] }.to_f,
                            total_cs: team_participants.sum { |p| (p[:minions_killed] || 0) + (p[:neutral_minions_killed] || 0) }.to_f
                          }
                        end
                      end

        participants.each do |participant_data|
          player = organization.players.find_by(riot_puuid: participant_data[:puuid])
          next unless player

          puts "SyncMatchJob Debug: Player #{player.summoner_name} - Items: #{participant_data[:items]}"
          puts "SyncMatchJob Debug: Raw Participant Keys: #{participant_data.keys}"

          team_stats = team_totals[participant_data[:team_id]]
          damage_share = if team_stats && team_stats[:total_damage].positive?
                           participant_data[:total_damage_dealt] / team_stats[:total_damage]
                         else
                           0
                         end
          gold_share = if team_stats && team_stats[:total_gold].positive?
                         participant_data[:gold_earned] / team_stats[:total_gold]
                       else
                         0
                       end

          # Calculate CS (minions + jungle minions)
          cs_total = (participant_data[:minions_killed] || 0) + (participant_data[:neutral_minions_killed] || 0)

          PlayerMatchStat.create!(
            match: match,
            player: player,
            role: normalize_role(participant_data[:role]),
            champion: participant_data[:champion_name],
            kills: participant_data[:kills],
            deaths: participant_data[:deaths],
            assists: participant_data[:assists],
            gold_earned: participant_data[:gold_earned],
            damage_dealt_total: participant_data[:total_damage_dealt],
            damage_taken: participant_data[:total_damage_taken],
            cs: cs_total,
            vision_score: participant_data[:vision_score],
            wards_placed: participant_data[:wards_placed],
            wards_destroyed: participant_data[:wards_killed],
            first_blood: participant_data[:first_blood_kill],
            double_kills: participant_data[:double_kills],
            triple_kills: participant_data[:triple_kills],
            quadra_kills: participant_data[:quadra_kills],
            penta_kills: participant_data[:penta_kills],
            performance_score: calculate_performance_score(participant_data),
            items: participant_data[:items],
            runes: participant_data[:runes],
            summoner_spell_1: participant_data[:summoner_spell_1],
            summoner_spell_2: participant_data[:summoner_spell_2],
            damage_share: damage_share,
            gold_share: gold_share
          )
        end
      end

      def determine_match_type(game_mode, participants, organization)
        # Count how many org players are in this match
        our_player_puuids = organization.players.pluck(:riot_puuid).compact
        our_participants = participants.select { |p| our_player_puuids.include?(p[:puuid]) }

        # If we have 5 or more players from the org on the same team, it's a competitive match
        # Otherwise, it's solo queue (classified as 'scrim' for now)
        if our_participants.size >= 5
          # Check if all our players are on the same team
          team_ids = our_participants.map { |p| p[:team_id] }.uniq
          team_ids.size == 1 ? 'official' : 'scrim'
        else
          'scrim' # Solo queue / ranked games
        end
      end

      def determine_team_victory(participants, organization)
        our_player_puuids = organization.players.pluck(:riot_puuid).compact
        our_participants = participants.select { |p| our_player_puuids.include?(p[:puuid]) }

        return nil if our_participants.empty?

        our_participants.first[:win]
      end

      def normalize_role(role)
        role_mapping = {
          'top' => 'top',
          'jungle' => 'jungle',
          'middle' => 'mid',
          'mid' => 'mid',
          'bottom' => 'adc',
          'adc' => 'adc',
          'utility' => 'support',
          'support' => 'support'
        }

        role_mapping[role&.downcase] || 'mid'
      end

      def calculate_performance_score(participant_data)
        # Simple performance score calculation
        # This can be made more sophisticated
        # future work
        kda = calculate_kda(
          kills: participant_data[:kills],
          deaths: participant_data[:deaths],
          assists: participant_data[:assists]
        )

        base_score = kda * 10
        damage_score = (participant_data[:total_damage_dealt] / 1000.0)
        vision_score = participant_data[:vision_score] || 0

        (base_score + (damage_score * 0.1) + vision_score).round(2)
      end

      def calculate_kda(kills:, deaths:, assists:)
        total = (kills + assists).to_f
        return total if deaths.zero?

        total / deaths
      end
    end
  end
end
