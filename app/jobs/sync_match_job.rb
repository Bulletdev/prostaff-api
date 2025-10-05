class SyncMatchJob < ApplicationJob
  queue_as :default

  retry_on RiotApiService::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on RiotApiService::RiotApiError, wait: 1.minute, attempts: 3

  def perform(match_id, organization_id, region = 'BR')
    organization = Organization.find(organization_id)
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
      patch_version: match_data[:game_version],
      victory: determine_team_victory(match_data[:participants], organization)
    )
  end

  def create_player_match_stats(match, participants, organization)
    participants.each do |participant_data|
      # Find player by PUUID
      player = organization.players.find_by(riot_puuid: participant_data[:puuid])
      next unless player

      PlayerMatchStat.create!(
        match: match,
        player: player,
        role: normalize_role(participant_data[:role]),
        champion: participant_data[:champion_name],
        kills: participant_data[:kills],
        deaths: participant_data[:deaths],
        assists: participant_data[:assists],
        gold_earned: participant_data[:gold_earned],
        total_damage_dealt: participant_data[:total_damage_dealt],
        total_damage_taken: participant_data[:total_damage_taken],
        minions_killed: participant_data[:minions_killed],
        jungle_minions_killed: participant_data[:neutral_minions_killed],
        vision_score: participant_data[:vision_score],
        wards_placed: participant_data[:wards_placed],
        wards_killed: participant_data[:wards_killed],
        champion_level: participant_data[:champion_level],
        first_blood_kill: participant_data[:first_blood_kill],
        double_kills: participant_data[:double_kills],
        triple_kills: participant_data[:triple_kills],
        quadra_kills: participant_data[:quadra_kills],
        penta_kills: participant_data[:penta_kills],
        performance_score: calculate_performance_score(participant_data)
      )
    end
  end

  def determine_match_type(game_mode)
    case game_mode.upcase
    when 'CLASSIC' then 'official'
    when 'ARAM' then 'scrim'
    else 'scrim'
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
    kda = participant_data[:deaths].zero? ?
          (participant_data[:kills] + participant_data[:assists]).to_f :
          (participant_data[:kills] + participant_data[:assists]).to_f / participant_data[:deaths]

    base_score = kda * 10
    damage_score = (participant_data[:total_damage_dealt] / 1000.0)
    vision_score = participant_data[:vision_score] || 0

    (base_score + damage_score * 0.1 + vision_score).round(2)
  end
end
