# frozen_string_literal: true

module Matches
  # Background job that fetches full match data from the Riot API and persists
  # per-player stats, items, and runes for a given match ID and organization.
  class SyncMatchJob < ApplicationJob
    queue_as :default

    # retry_on RiotApiService::RateLimitError, wait: :polynomially_longer, attempts: 5
    # retry_on RiotApiService::RiotApiError, wait: 1.minute, attempts: 3

    def perform(match_id, organization_id, region = 'BR', force_update: false)
      # Set organization context for multi-tenant scoping
      Current.organization_id = organization_id

      puts "SyncMatchJob: Starting sync for #{match_id} (force_update: #{force_update})"
      $stdout.flush
      organization = Organization.find(organization_id)
      riot_service = RiotApiService.new

      begin
        match_data = riot_service.get_match_details(
          match_id: match_id,
          region: region
        )
      rescue StandardError => e
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
    ensure
      # Clean up context
      Current.organization_id = nil
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
      Rails.logger.info("[SyncMatchJob] Creating player stats for #{participants.size} participants")

      our_player_puuids = organization.players.pluck(:riot_puuid).compact
      our_participants  = participants.select { |p| our_player_puuids.include?(p[:puuid]) }
      is_competitive    = our_participants.size >= 5

      team_totals  = calculate_team_totals(participants, our_participants, is_competitive)
      opponent_map = build_opponent_map(participants)
      player_index = organization.players.where(riot_puuid: our_player_puuids).index_by(&:riot_puuid)

      records = build_stat_records(match, participants, player_index, team_totals, opponent_map)
      return if records.empty?

      records = deduplicate_stat_records(records)
      PlayerMatchStat.insert_all(records)
    end

    # Builds a hash mapping each participant's puuid to the champion name of their
    # lane opponent (same teamPosition on the opposing team).
    # Returns an empty hash when the match has an unexpected team structure.
    def build_opponent_map(participants)
      by_team = participants.group_by { |p| p[:team_id] }
      teams = by_team.keys
      return {} unless teams.size == 2

      result = {}
      teams.each do |team_id|
        other_team_id = teams.find { |t| t != team_id }
        other_team = by_team[other_team_id] || []

        by_team[team_id].each do |participant|
          role = participant[:role]
          next if role.blank?

          opponent = other_team.find { |o| o[:role] == role }
          result[participant[:puuid]] = opponent&.dig(:champion_name)
        end
      end

      result
    end

    def calculate_team_totals(participants, our_participants, is_competitive)
      source = is_competitive ? our_participants : participants
      source.group_by { |p| p[:team_id] }.transform_values do |team_participants|
        {
          total_damage: team_participants.sum { |p| p[:total_damage_dealt] }.to_f,
          total_gold:   team_participants.sum { |p| p[:gold_earned] }.to_f,
          total_kills:  team_participants.sum { |p| p[:kills].to_i }.to_f,
          total_cs:     team_participants.sum { |p| (p[:minions_killed] || 0) + (p[:neutral_minions_killed] || 0) }.to_f
        }
      end
    end

    def build_stat_records(match, participants, player_index, team_totals, opponent_map)
      records = []
      now = Time.current

      participants.each do |participant_data|
        player = player_index[participant_data[:puuid]]
        next unless player

        attrs = build_stat_attributes(match, player, participant_data, team_totals, opponent_map)
        records << attrs.merge(created_at: now, updated_at: now)
      end

      records
    end

    def deduplicate_stat_records(records)
      seen = {}
      records.each_with_object([]) do |r, acc|
        key = [r[:match_id], r[:player_id]]
        next if seen[key]

        seen[key] = true
        acc << r
      end
    end

    def build_stat_attributes(match, player, participant_data, team_totals, opponent_map)
      team_stats       = team_totals[participant_data[:team_id]]
      damage_share     = calc_share(participant_data[:total_damage_dealt], team_stats&.dig(:total_damage))
      gold_share       = calc_share(participant_data[:gold_earned], team_stats&.dig(:total_gold))
      cs_total         = (participant_data[:minions_killed] || 0) + (participant_data[:neutral_minions_killed] || 0)
      duration_minutes = match.game_duration.to_f / 60.0
      kp               = calc_kill_participation(participant_data, team_stats)

      base_stat_fields(match, player, participant_data, opponent_map, cs_total)
        .merge(combat_stat_fields(participant_data))
        .merge(vision_and_objective_fields(participant_data))
        .merge(share_and_spell_fields(participant_data, damage_share, gold_share))
        .merge(rate_fields(cs_total, participant_data[:gold_earned], duration_minutes, kp))
    end

    def rate_fields(cs_total, gold_earned, duration_minutes, kill_participation)
      if duration_minutes > 0
        {
          cs_per_min:         (cs_total.to_f / duration_minutes).round(2),
          gold_per_min:       (gold_earned.to_f / duration_minutes).round(2),
          kill_participation: kill_participation
        }
      else
        { cs_per_min: 0.0, gold_per_min: 0.0, kill_participation: kill_participation }
      end
    end

    def calc_kill_participation(participant_data, team_stats)
      total_kills = team_stats&.dig(:total_kills).to_f
      return 0.0 if total_kills.zero?

      ((participant_data[:kills].to_i + participant_data[:assists].to_i) / total_kills).round(4)
    end

    def base_stat_fields(match, player, participant_data, opponent_map, cs_total)
      {
        match_id: match.id,
        player_id: player.id,
        role: normalize_role(participant_data[:role]),
        champion: participant_data[:champion_name],
        opponent_champion: opponent_map[participant_data[:puuid]],
        kills: participant_data[:kills],
        deaths: participant_data[:deaths],
        assists: participant_data[:assists],
        gold_earned: participant_data[:gold_earned],
        damage_dealt_total: participant_data[:total_damage_dealt],
        damage_taken: participant_data[:total_damage_taken],
        cs: cs_total,
        neutral_minions_killed: participant_data[:neutral_minions_killed],
        performance_score: calculate_performance_score(participant_data),
        items: participant_data[:items],
        runes: participant_data[:runes]
      }
    end

    def combat_stat_fields(participant_data)
      {
        double_kills: participant_data[:double_kills],
        triple_kills: participant_data[:triple_kills],
        quadra_kills: participant_data[:quadra_kills],
        penta_kills: participant_data[:penta_kills],
        first_blood: participant_data[:first_blood_kill],
        first_tower: participant_data[:first_tower_kill],
        objectives_stolen: participant_data[:objectives_stolen],
        crowd_control_score: participant_data[:crowd_control_score],
        total_time_dead: participant_data[:total_time_dead],
        damage_to_turrets: participant_data[:damage_to_turrets],
        damage_shielded_teammates: participant_data[:damage_shielded_teammates],
        healing_to_teammates: participant_data[:healing_to_teammates]
      }
    end

    def vision_and_objective_fields(participant_data)
      {
        vision_score: participant_data[:vision_score],
        wards_placed: participant_data[:wards_placed],
        wards_destroyed: participant_data[:wards_killed],
        control_wards_purchased: participant_data[:control_wards_purchased],
        cs_at_10: participant_data[:cs_at_10],
        turret_plates_destroyed: participant_data[:turret_plates_destroyed],
        pings: participant_data[:pings] || {}
      }
    end

    def share_and_spell_fields(participant_data, damage_share, gold_share)
      {
        summoner_spell_1: participant_data[:summoner_spell_1],
        summoner_spell_2: participant_data[:summoner_spell_2],
        damage_share: damage_share,
        gold_share: gold_share,
        spell_q_casts: participant_data[:spell_q_casts],
        spell_w_casts: participant_data[:spell_w_casts],
        spell_e_casts: participant_data[:spell_e_casts],
        spell_r_casts: participant_data[:spell_r_casts],
        summoner_spell_1_casts: participant_data[:summoner_spell_1_casts],
        summoner_spell_2_casts: participant_data[:summoner_spell_2_casts]
      }
    end

    def calc_share(value, total)
      return 0 unless total&.positive?

      value / total
    end

    def determine_match_type(_game_mode, participants, organization)
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
