# frozen_string_literal: true

# Backfills the expanded player stats into existing CompetitiveMatch records.
#
# After Fix-2 expanded build_picks from 7 to 17+ fields, matches already in the
# database have our_picks / opponent_picks with only the old 7-field format.
# This task rebuilds those arrays from game_stats['participants'], which stores
# the full participant payload from the ProStaff Scraper.
#
# For records where game_stats['participants'] is empty (rare — legacy before
# enrichment was introduced), the task re-fetches from the scraper HTTP API and
# re-runs the full import pipeline.
#
# Usage:
#   bundle exec rake competitive:backfill_picks
#   bundle exec rake competitive:backfill_picks ORGANIZATION_ID=42
#   bundle exec rake competitive:backfill_picks DRY_RUN=true
#
# Environment variables:
#   ORGANIZATION_ID  — if set, only backfill matches for that org (integer)
#   DRY_RUN          — if "true", log changes but do not save (default: false)

# rubocop:disable Metrics/BlockLength
namespace :competitive do
  desc 'Backfill full player stats (cs, gold, damage, items, runes…) into existing competitive_matches'
  task backfill_picks: :environment do
    dry_run = ENV['DRY_RUN'].to_s.downcase == 'true'
    org_id  = ENV['ORGANIZATION_ID']

    importer_klass = Competitive::Services::ScraperImporterService

    puts "[competitive:backfill_picks] Starting#{' (DRY RUN)' if dry_run}…"

    scope = CompetitiveMatch.where('jsonb_array_length(our_picks) > 0')
    scope = scope.where(organization_id: org_id) if org_id.present?

    # Only matches where our_picks is missing the expanded fields (e.g. 'cs')
    needs_backfill = scope.select do |match|
      match.our_picks.first&.key?('cs').blank?
    end

    puts "[competitive:backfill_picks] #{needs_backfill.size} matches need backfill " \
         "(out of #{scope.count} total with picks)"

    if needs_backfill.empty?
      puts '[competitive:backfill_picks] Nothing to do. All picks already have expanded fields.'
      next
    end

    updated   = 0
    skipped   = 0
    errors    = 0

    # Build a throwaway importer instance (organization doesn't matter for helpers)
    dummy_org = needs_backfill.first.organization
    importer  = importer_klass.new(dummy_org)

    needs_backfill.each_with_index do |competitive_match, idx|
      print "\r[#{idx + 1}/#{needs_backfill.size}] processing match #{competitive_match.id}…"

      participants = competitive_match.game_stats&.dig('participants').presence

      # Fallback: re-fetch from scraper when participants are not cached in game_stats
      if participants.blank?
        participants = fetch_participants_from_scraper(competitive_match)

        if participants.blank?
          puts "\n  [SKIP] #{competitive_match.external_match_id} — no participants available"
          skipped += 1
          next
        end
      end

      our_team = competitive_match.our_team_name
      opp_team = competitive_match.opponent_team_name

      new_our_picks  = importer.send(:build_picks, participants, our_team)
      new_opp_picks  = importer.send(:build_picks, participants, opp_team)

      if dry_run
        gained_keys = (new_our_picks.first&.keys.to_a - competitive_match.our_picks.first&.keys.to_a).join(', ')
        puts "\n  [DRY RUN] #{competitive_match.external_match_id} — our_picks would gain keys: #{gained_keys}"
        updated += 1
        next
      end

      competitive_match.update!(our_picks: new_our_picks, opponent_picks: new_opp_picks)
      updated += 1
    rescue StandardError => e
      puts "\n  [ERROR] #{competitive_match.external_match_id}: #{e.message}"
      errors += 1
    end

    puts "\n\n[competitive:backfill_picks] Done."
    puts "  Updated : #{updated}"
    puts "  Skipped : #{skipped}"
    puts "  Errors  : #{errors}"
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def fetch_participants_from_scraper(competitive_match)
    scraper = ProStaffScraperService.new
    match   = scraper.fetch_match(competitive_match.external_match_id)
    match['participants']
  rescue ProStaffScraperService::NotFoundError
    Rails.logger.warn(
      "[backfill_competitive_picks] Match not found in scraper: #{competitive_match.external_match_id}"
    )
    nil
  rescue ProStaffScraperService::ScraperError => e
    Rails.logger.error(
      "[backfill_competitive_picks] Scraper error for #{competitive_match.external_match_id}: #{e.message}"
    )
    nil
  end
end
# rubocop:enable Metrics/BlockLength
