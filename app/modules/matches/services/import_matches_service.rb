# frozen_string_literal: true

# Fetches match IDs from Riot API for a player and enqueues SyncMatchJob
# for each new match. Returns counts synchronously so the caller can
# respond with meaningful feedback without waiting for individual syncs.
class ImportMatchesService
  def initialize(player:, organization:, count: 20, force_update: false)
    @player       = player
    @organization = organization
    @count        = count
    @force_update = force_update
  end

  # @return [Hash] counts: total_matches_found, imported, already_imported, updated
  def call
    match_ids = fetch_match_ids
    tally = { imported: 0, already_imported: 0, updated: 0 }

    match_ids.each { |id| process_match(id, tally) }

    tally.merge(total_matches_found: match_ids.size)
  end

  private

  def fetch_match_ids
    RiotApiService.new.get_match_history(
      puuid: @player.riot_puuid,
      region: region,
      count: @count
    )
  end

  def process_match(match_id, tally)
    if Match.exists?(riot_match_id: match_id)
      handle_existing_match(match_id, tally)
    else
      SyncMatchJob.perform_later(match_id, @organization.id, region)
      tally[:imported] += 1
    end
  end

  def handle_existing_match(match_id, tally)
    if @force_update
      SyncMatchJob.perform_later(match_id, @organization.id, region, force_update: true)
      tally[:updated] += 1
    else
      tally[:already_imported] += 1
    end
  end

  def region
    @player.region || 'BR'
  end
end
