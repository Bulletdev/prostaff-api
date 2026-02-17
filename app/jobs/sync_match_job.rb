# frozen_string_literal: true

class SyncMatchJob < ApplicationJob
  queue_as :default

  retry_on RiotApiService::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on RiotApiService::RiotApiError, wait: 1.minute, attempts: 3

  ROLE_MAPPING = {
    'top' => 'top', 'toplaner' => 'top', 'topo' => 'top',
    'jungle' => 'jungle', 'selva' => 'jungle', 'jungler' => 'jungle',
    'middle' => 'mid', 'mid' => 'mid', 'meio' => 'mid',
    'bottom' => 'adc', 'adc' => 'adc', 'adcarry' => 'adc', 'carry' => 'adc', 'atirador' => 'adc',
    'utility' => 'support', 'support' => 'support', 'suporte' => 'support'
  }.freeze

  SPELL_MAPPING = {
    1 => 'SummonerBoost',       # Cleanse
    3 => 'SummonerExhaust',     # Exhaust
    4 => 'SummonerFlash',       # Flash
    6 => 'SummonerHaste',       # Ghost
    7 => 'SummonerHeal',        # Heal
    11 => 'SummonerSmite',      # Smite
    12 => 'SummonerTeleport',   # Teleport
    13 => 'SummonerMana',       # Clarity
    14 => 'SummonerDot',        # Ignite
    21 => 'SummonerBarrier',    # Barrier
    30 => 'SummonerPoroRecall', # To the King!
    31 => 'SummonerPoroThrow',  # Poro Toss
    32 => 'SummonerSnowball',   # Mark/Dash (ARAM)
    39 => 'SummonerSnowURFBattle' # Ultra Rapid Fire
  }.freeze

  def perform(match_id, organization_id, region = 'BR')
    organization = Organization.find(organization_id)

    # Set organization context for the background job
    Current.set(organization_id: organization_id) do
      riot_service = RiotApiService.new

      match_data = riot_service.get_match_details(
        match_id: match_id,
        region: region
      )

      # Check if match already exists
      match = Match.find_by(riot_match_id: match_data[:match_id])
      if match.present?
        Rails.logger.info("Match #{match_id} already exists")
        return
      end

      # Create match record
      match = create_match_record(match_data, organization)

      # Create player match stats
      create_player_match_stats(match, match_data[:participants], organization)

      Rails.logger.info("Successfully synced match #{match_id}")
    end
  rescue RiotApiService::NotFoundError => e
    Rails.logger.error("Match not found in Riot API: #{match_id} - #{e.message}")
  rescue StandardError => e
    Rails.logger.error("Failed to sync match #{match_id}: #{e.message}")
    raise
  end

  private

  def create_match_record(match_data, organization)
    Match.create!(
      organization: organization,
      riot_match_id: match_data[:match_id],
      match_type: determine_match_type(match_data[:game_mode]),
      game_start: match_data[:game_creation],
      game_end: match_data[:game_creation] + match_data[:game_duration].seconds,
      game_duration: match_data[:game_duration],
      game_version: match_data[:game_version],
      victory: determine_team_victory(match_data[:participants], organization)
    )
  end

  def create_player_match_stats(match, participants, organization)
    Rails.logger.info "Creating stats for #{participants.count} participants"
    created_count = 0

    participants.each do |participant_data|
      player = organization.players.find_by(riot_puuid: participant_data[:puuid])
      unless player
        Rails.logger.debug "Participant PUUID #{participant_data[:puuid][0..20]}... not found in organization"
        next
      end

      create_participant_stat(match, player, participant_data)
      created_count += 1
    end

    Rails.logger.info "Created #{created_count} player match stats"
  end

  def create_participant_stat(match, player, participant_data)
    Rails.logger.info "Creating stat for player: #{player.summoner_name}"
    PlayerMatchStat.create!(build_stat_attributes(match, player, participant_data))
    Rails.logger.info "Stat created successfully for #{player.summoner_name}"
  end

  def build_stat_attributes(match, player, pd)
    {
      match: match,
      player: player,
      role: normalize_role(pd[:role]),
      champion: pd[:champion_name],
      kills: pd[:kills],
      deaths: pd[:deaths],
      assists: pd[:assists],
      gold_earned: pd[:gold_earned],
      damage_dealt_champions: pd[:total_damage_dealt],
      damage_dealt_total: pd[:total_damage_dealt],
      damage_taken: pd[:total_damage_taken],
      cs: pd[:minions_killed].to_i + pd[:neutral_minions_killed].to_i,
      vision_score: pd[:vision_score],
      wards_placed: pd[:wards_placed],
      wards_destroyed: pd[:wards_killed],
      first_blood: pd[:first_blood_kill],
      double_kills: pd[:double_kills],
      triple_kills: pd[:triple_kills],
      quadra_kills: pd[:quadra_kills],
      penta_kills: pd[:penta_kills],
      items: pd[:items] || [],
      item_build_order: pd[:item_build_order] || [],
      trinket: pd[:trinket],
      summoner_spell_1: map_summoner_spell(pd[:summoner_spell_1]),
      summoner_spell_2: map_summoner_spell(pd[:summoner_spell_2]),
      runes: pd[:runes] || [],
      performance_score: calculate_performance_score(pd)
    }
  end

  def determine_match_type(game_mode)
    case game_mode.upcase
    when 'CLASSIC' then 'official'
    else 'scrim' # covers ARAM and other game modes
    end
  end

  def determine_team_victory(participants, organization)
    # Find our players in the match
    our_player_puuids = organization.players.pluck(:riot_puuid).compact
    our_participants = participants.select { |p| our_player_puuids.include?(p[:puuid]) }

    return nil if our_participants.empty?

    # Check if our players won
    our_participants.first[:win]
  end

  def normalize_role(role)
    ROLE_MAPPING[role&.downcase] || 'mid'
  end

  def calculate_performance_score(participant_data)
    # Simple performance score calculation
    # This can be made more sophisticated
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

  # Map summoner spell ID to name (Riot Data Dragon spell IDs)
  def map_summoner_spell(spell_id)
    SPELL_MAPPING[spell_id] || "SummonerSpell#{spell_id}"
  end
end
